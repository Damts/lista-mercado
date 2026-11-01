import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models/item.dart';
import '../state.dart';

class MonthlyItemsPage extends StatefulWidget {
  final int houseId;
  final int listId;
  const MonthlyItemsPage({
    super.key,
    required this.houseId,
    required this.listId,
  });
  @override
  State<MonthlyItemsPage> createState() => _MonthlyItemsPageState();
}

class _MonthlyItemsPageState extends State<MonthlyItemsPage> {
  final _scroll = ScrollController();
  List<Item> _items = [];
  bool _loading = true, _loadingMore = false, _hasMore = false;
  String? _cursor, _error;
  bool _closed = false;
  int? _year, _month;
  Map<String, dynamic>? _copySource;
  String? _copySourceError;
  bool _checkingCopySource = false;
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_nearEnd);
    _load(firstPage: true);
  }

  @override
  void dispose() {
    _scroll.removeListener(_nearEnd);
    _scroll.dispose();
    super.dispose();
  }

  void _nearEnd() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 240 &&
        !_loading &&
        !_loadingMore &&
        _hasMore &&
        _error == null) {
      _load(firstPage: false);
    }
  }

  void _scheduleFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nearEnd();
    });
  }

  Future<void> _load({required bool firstPage}) async {
    if (firstPage) {
      setState(() {
        _loading = true;
        _error = null;
        _cursor = null;
        _hasMore = false;
        _copySource = null;
        _copySourceError = null;
        _checkingCopySource = _items.isNotEmpty;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    }
    final state = context.read<AppState>();
    try {
      final api = state.api;
      if (firstPage) {
        final listsResponse =
            await api.request(
                  'GET',
                  '/v1/casas/${widget.houseId}/listas',
                  houseId: widget.houseId,
                )
                as Map<String, dynamic>;
        final lists = (listsResponse['data'] as List)
            .cast<Map<String, dynamic>>();
        final matches = lists.where(
          (list) => (list['id'] as num).toInt() == widget.listId,
        );
        if (matches.isEmpty) throw ApiException(404, 'Lista não encontrada.');
        final match = matches.first;
        _closed = match['fechado_em'] != null;
        _year = (match['ano'] as num).toInt();
        _month = (match['mes'] as num).toInt();
        if (!_closed) {
          _checkingCopySource = true;
          try {
            _copySource = await _latestSourceWithItems(lists, match);
          } catch (error) {
            if (error is ApiException && error.status == 401) rethrow;
            _copySourceError =
                'Não foi possível verificar a lista de origem. Tente novamente.';
          } finally {
            _checkingCopySource = false;
          }
        }
      }
      final path = firstPage
          ? '/v1/listas/${widget.listId}/itens'
          : '/v1/listas/${widget.listId}/itens?cursor=${Uri.encodeQueryComponent(_cursor!)}';
      final response =
          await api.request('GET', path, houseId: widget.houseId)
              as Map<String, dynamic>;
      final data = response['data'], meta = response['meta'];
      if (data is! List ||
          meta is! Map<String, dynamic> ||
          meta['has_more'] is! bool) {
        throw const FormatException('Resposta paginada inválida.');
      }
      final hasMore = meta['has_more'] as bool;
      final nextCursor = meta['next_cursor'];
      if ((nextCursor != null && nextCursor is! String) ||
          (hasMore && (nextCursor == null || nextCursor.isEmpty))) {
        throw const FormatException('Cursor de paginação inválido.');
      }
      final pageItems = data
          .map((raw) => Item.fromJson(raw as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = firstPage ? pageItems : [..._items, ...pageItems];
        _hasMore = hasMore;
        _cursor = nextCursor as String?;
        _loading = false;
        _loadingMore = false;
      });
      _scheduleFillViewport();
    } catch (error) {
      if (error is ApiException && error.status == 401) {
        await state.clearSession();
      }
      if (!mounted) return;
      setState(() {
        _error = error is ApiException && error.status == 404
            ? 'Lista não encontrada nesta casa. Volte às listas e selecione outra.'
            : 'Não foi possível carregar os itens. Verifique a conexão e tente novamente.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _latestSourceWithItems(
    List<Map<String, dynamic>> lists,
    Map<String, dynamic> destination,
  ) async {
    final destinationYear = (destination['ano'] as num).toInt();
    final destinationMonth = (destination['mes'] as num).toInt();
    final candidates =
        lists.where((list) {
          final year = (list['ano'] as num).toInt();
          final month = (list['mes'] as num).toInt();
          return year < destinationYear ||
              (year == destinationYear && month < destinationMonth);
        }).toList()..sort((left, right) {
          final yearOrder = (right['ano'] as num).compareTo(left['ano'] as num);
          return yearOrder != 0
              ? yearOrder
              : (right['mes'] as num).compareTo(left['mes'] as num);
        });

    for (final candidate in candidates) {
      final listId = (candidate['id'] as num).toInt();
      final response = await context.read<AppState>().api.request(
        'GET',
        '/v1/listas/$listId/itens',
        houseId: widget.houseId,
      );
      if (response is! Map<String, dynamic> || response['data'] is! List) {
        throw const FormatException('Resposta da origem inválida.');
      }
      if ((response['data'] as List).isNotEmpty) return candidate;
    }
    return null;
  }

  Future<void> _copyItems() async {
    final source = _copySource;
    if (source == null ||
        _closed ||
        _items.isNotEmpty ||
        _checkingCopySource ||
        _copying) {
      return;
    }
    final sourceId = (source['id'] as num).toInt();
    final appState = context.read<AppState>();
    setState(() => _copying = true);
    try {
      await appState.api.request(
        'POST',
        '/v1/listas/${widget.listId}/copiar-de/$sourceId',
        houseId: widget.houseId,
      );
      await _load(firstPage: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Itens copiados para a lista deste mês.'),
          ),
        );
      }
    } on ApiException catch (error) {
      if (error.status == 401) {
        await appState.clearSession();
      }
      if (error.status == 409 && error.errorCode == 'lista_nao_vazia') {
        await _load(firstPage: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A lista do mês já recebeu itens. Revise a lista antes de tentar novamente.',
              ),
            ),
          );
        }
      } else if (mounted) {
        final message = error.status == 404
            ? 'A lista de origem não está disponível nesta casa. Atualize e tente novamente.'
            : error.status == 422
            ? 'A lista de origem mudou. Atualize e tente novamente.'
            : error.message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível copiar os itens. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Widget _copyCard() {
    final source = _copySource;
    final sourceMonth = source == null ? null : (source['mes'] as num).toInt();
    final sourceYear = source == null ? null : (source['ano'] as num).toInt();
    final destinationHasItems = _items.isNotEmpty;
    final message = _checkingCopySource
        ? 'Verificando a última lista com itens…'
        : _copySourceError != null
        ? _copySourceError!
        : source == null
        ? 'Não há uma lista anterior com itens para copiar.'
        : 'Copiando de ${_monthName(sourceMonth!).toLowerCase()}/$sourceYear';
    final disabledReason = destinationHasItems
        ? 'A cópia só fica disponível quando a lista deste mês está vazia.'
        : null;
    final canCopy =
        source != null &&
        _copySourceError == null &&
        !_checkingCopySource &&
        !destinationHasItems &&
        !_copying &&
        !_loading;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            if (disabledReason != null) ...[
              const SizedBox(height: 4),
              Text(
                disabledReason,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_copySourceError != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _loading ? null : () => _load(firstPage: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar verificar novamente'),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: canCopy ? _copyItems : null,
              icon: _copying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.content_copy),
              label: Text(
                _copying ? 'Copiando…' : 'Copiar itens para este mês',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _year == null || _month == null
        ? 'Itens da lista'
        : '${_monthName(_month!)} de $_year';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Voltar para listas',
          onPressed: () => context.go('/casas/${widget.houseId}/listas'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (_closed)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.lock_outline, semanticLabel: 'Lista fechada'),
            ),
          if (!_closed && _year != null)
            IconButton(
              tooltip: 'Abrir lista para editar',
              onPressed: () => context.go('/lista'),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando itens da lista',
              ),
            )
          : Column(
              children: [
                if (!_closed && _year != null) _copyCard(),
                Expanded(
                  child: _error != null && _items.isEmpty
                      ? _errorView()
                      : _items.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () => _load(firstPage: true),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 100),
                              const Icon(
                                Icons.shopping_basket_outlined,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Center(
                                child: Text('Esta lista está vazia'),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  _closed
                                      ? 'Lista fechada · somente leitura'
                                      : 'Ainda não há itens neste mês.',
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(firstPage: true),
                          child: ListView.builder(
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount:
                                _items.length +
                                (_closed ? 1 : 0) +
                                (_hasMore || _error != null ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_closed && index == 0) {
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.lock_outline),
                                    title: const Text(
                                      'Lista fechada · somente leitura',
                                    ),
                                    subtitle: const Text(
                                      'Os itens deste mês não podem ser alterados.',
                                    ),
                                  ),
                                );
                              }
                              final itemIndex = index - (_closed ? 1 : 0);
                              if (itemIndex < _items.length) {
                                return _ItemTile(item: _items[itemIndex]);
                              }
                              if (_error != null) {
                                return Center(
                                  child: TextButton.icon(
                                    onPressed: () => _load(firstPage: false),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Tentar carregar mais'),
                                  ),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    semanticsLabel: 'Carregando mais itens',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _load(firstPage: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
          TextButton.icon(
            onPressed: () => context.go('/casas/${widget.houseId}/listas'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar para listas'),
          ),
        ],
      ),
    ),
  );

  String _monthName(int month) {
    const names = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return month >= 1 && month <= 12 ? names[month - 1] : 'Mês $month';
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  const _ItemTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final price = item.price == null
        ? 'Preço não informado'
        : 'R\$ ${item.price!.replaceFirst('.', ',')}';
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(
          item.bought
              ? Icons.check_circle_outline
              : Icons.shopping_basket_outlined,
          semanticLabel: item.bought ? 'Comprado' : 'Não comprado',
        ),
        title: Text(item.name),
        subtitle: Text('${item.quantity} ${item.measure} · $price'),
      ),
    );
  }
}
