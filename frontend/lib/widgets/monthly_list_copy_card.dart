import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models/monthly_list.dart';
import '../state.dart';

class MonthlyListCopyCard extends StatefulWidget {
  final int houseId;
  final List<MonthlyList> lists;
  final MonthlyList destination;
  final bool destinationHasItems;
  final Future<void> Function() onCopied;

  const MonthlyListCopyCard({
    super.key,
    required this.houseId,
    required this.lists,
    required this.destination,
    required this.destinationHasItems,
    required this.onCopied,
  });

  @override
  State<MonthlyListCopyCard> createState() => _MonthlyListCopyCardState();
}

class _MonthlyListCopyCardState extends State<MonthlyListCopyCard> {
  MonthlyList? _source;
  String? _error;
  bool _checking = true;
  bool _copying = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _findSource();
  }

  @override
  void didUpdateWidget(covariant MonthlyListCopyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination.id != widget.destination.id ||
        !identical(oldWidget.lists, widget.lists)) {
      _findSource();
    }
  }

  Future<void> _findSource() async {
    final generation = ++_generation;
    setState(() {
      _checking = true;
      _error = null;
      _source = null;
    });
    final candidates =
        widget.lists.where((list) {
          return list.year < widget.destination.year ||
              (list.year == widget.destination.year &&
                  list.month < widget.destination.month);
        }).toList()..sort((left, right) {
          final yearOrder = right.year.compareTo(left.year);
          return yearOrder != 0 ? yearOrder : right.month.compareTo(left.month);
        });

    final appState = context.read<AppState>();
    try {
      final api = appState.api;
      for (final candidate in candidates) {
        final response = await api.request(
          'GET',
          '/v1/listas/${candidate.id}/itens',
          houseId: widget.houseId,
        );
        if (response is! Map<String, dynamic> || response['data'] is! List) {
          throw const FormatException('Resposta da lista de origem inválida.');
        }
        if ((response['data'] as List).isNotEmpty) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _source = candidate;
            _checking = false;
          });
          return;
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() => _checking = false);
    } on ApiException catch (exception) {
      if (exception.status == 401) {
        await appState.clearSession();
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _checking = false;
        _error = exception.status == 404
            ? 'Uma lista anterior não está disponível nesta casa.'
            : 'Não foi possível verificar a lista de origem. Tente novamente.';
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _checking = false;
        _error =
            'Não foi possível verificar a lista de origem. Tente novamente.';
      });
    }
  }

  Future<void> _copy() async {
    final source = _source;
    if (source == null ||
        _checking ||
        _copying ||
        _error != null ||
        widget.destinationHasItems) {
      return;
    }
    final appState = context.read<AppState>();
    setState(() => _copying = true);
    try {
      await appState.api.request(
        'POST',
        '/v1/listas/${widget.destination.id}/copiar-de/${source.id}',
        houseId: widget.houseId,
      );
      await widget.onCopied();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itens copiados para este mês.')),
      );
    } on ApiException catch (exception) {
      if (exception.status == 401) {
        await appState.clearSession();
      }
      if (exception.status == 409 && exception.errorCode == 'lista_nao_vazia') {
        await widget.onCopied();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A lista deste mês já tem itens. Atualizei a lista; revise antes de copiar.',
              ),
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _error = exception.status == 404 || exception.status == 422
              ? 'A lista de origem mudou. Verifique novamente antes de copiar.'
              : 'Não foi possível copiar os itens. Tente novamente.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível copiar os itens. Tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  String _sourceLabel(MonthlyList source) {
    final month = source.label.split(' ').first.toLowerCase();
    return 'Copiando de $month/${source.year}';
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final destinationHasItems = widget.destinationHasItems;
    final message = _checking
        ? 'Verificando a última lista com itens…'
        : _error ??
              (source == null
                  ? 'Não há uma lista anterior com itens para copiar.'
                  : _sourceLabel(source));
    final canCopy =
        source != null &&
        !_checking &&
        !_copying &&
        _error == null &&
        !destinationHasItems;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            if (destinationHasItems) ...[
              const SizedBox(height: 4),
              Text(
                'A cópia só fica disponível enquanto a lista deste mês estiver vazia.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _checking ? null : _findSource,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar verificar novamente'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: canCopy ? _copy : null,
              icon: _copying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Copiando itens',
                      ),
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
}
