import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';

class MonthlyListsPage extends StatefulWidget {
  final int houseId;
  const MonthlyListsPage({super.key, required this.houseId});

  @override
  State<MonthlyListsPage> createState() => _MonthlyListsPageState();
}

class _MonthlyListsPageState extends State<MonthlyListsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _lists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      final response =
          await state.api.request(
                'GET',
                '/v1/casas/${widget.houseId}/listas',
                houseId: widget.houseId,
              )
              as Map<String, dynamic>;
      final data = response['data'];
      if (data is! List) {
        throw const FormatException('Resposta de listas inválida.');
      }
      if (!mounted) return;
      setState(() {
        _lists = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (error) {
      if (error is ApiException && error.status == 401) {
        await state.clearSession();
      }
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  String _message(Object error) => error is ApiException && error.status == 404
      ? 'Casa não encontrada ou sem acesso. Volte para suas casas e tente novamente.'
      : error is ApiException
      ? 'Não foi possível carregar as listas. Verifique a conexão e tente novamente.'
      : 'Não foi possível carregar as listas. Tente novamente.';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final house = state.activeHouse?.id == widget.houseId
        ? state.activeHouse
        : state.houses.where((h) => h.id == widget.houseId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(house?.name ?? 'Listas mensais'),
        leading: IconButton(
          tooltip: 'Voltar para as casas',
          onPressed: () => context.go('/casas'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando listas mensais',
              ),
            )
          : _error != null
          ? _ErrorState(
              message: _error!,
              onRetry: _load,
              onBack: () => context.go('/casas'),
            )
          : _lists.isEmpty
          ? RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.calendar_month_outlined, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('Nenhuma lista mensal disponível')),
                  SizedBox(height: 6),
                  Center(child: Text('Puxe para atualizar.')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _lists.length,
                itemBuilder: (context, index) {
                  final list = _lists[index];
                  final id = (list['id'] as num).toInt();
                  final year = (list['ano'] as num).toInt();
                  final month = (list['mes'] as num).toInt();
                  final closed = list['fechado_em'] != null;
                  return Card(
                    child: ListTile(
                      minVerticalPadding: 12,
                      leading: Icon(
                        closed
                            ? Icons.lock_outline
                            : Icons.calendar_month_outlined,
                      ),
                      title: Text('${_monthName(month)} de $year'),
                      subtitle: Text(
                        closed
                            ? 'Lista fechada · somente leitura'
                            : 'Lista aberta',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.go('/casas/${widget.houseId}/listas/$id'),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _monthName(int month) {
    const names = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    if (month < 1 || month > 12) return 'Mês $month';
    final name = names[month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onBack;
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });
  @override
  Widget build(BuildContext context) => Center(
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
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar para as casas'),
          ),
        ],
      ),
    ),
  );
}
