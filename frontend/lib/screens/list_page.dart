import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../models/monthly_list.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/item_list_view.dart';
import '../widgets/monthly_list_copy_card.dart';

class ListPage extends StatelessWidget {
  const ListPage({super.key});

  Future<void> _addItem(BuildContext context, AppState state) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddItemDialog(
        onSave: (name, quantity, price) =>
            state.add(name, quantity: quantity, price: price),
      ),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item adicionado.')));
    }
  }

  Widget _body(BuildContext context, AppState state) {
    if (state.houseLoading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando casa'),
      );
    }
    if (state.houseError != null) {
      return _HouseErrorState(
        message: state.houseError!,
        onRetry: state.retryHouse,
        onBack: () => context.go('/casas'),
      );
    }
    if (state.listsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Carregando listas mensais',
        ),
      );
    }
    if (state.listsError != null) {
      return _HouseErrorState(
        message: state.listsError!,
        onRetry: state.loadMonthlyLists,
        onBack: () => context.go('/casas'),
      );
    }
    if (state.activeList == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 40),
              const SizedBox(height: 12),
              const Text('Nenhuma lista mensal disponível.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state.loadMonthlyLists,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DropdownButtonFormField<MonthlyList>(
            key: ValueKey(state.activeList!.id),
            initialValue: state.activeList,
            decoration: const InputDecoration(labelText: 'Lista do mês'),
            items: state.monthlyLists
                .map(
                  (list) => DropdownMenuItem(
                    value: list,
                    child: Text(
                      '${list.label}${list.isClosed ? ' · Fechado' : ''}',
                    ),
                  ),
                )
                .toList(),
            onChanged: state.itemsLoading
                ? null
                : (list) {
                    if (list != null) state.selectMonthlyList(list);
                  },
          ),
        ),
        if (state.activeList!.isClosed)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, semanticLabel: 'Lista fechada'),
                  SizedBox(width: 8),
                  Expanded(child: Text('Mês fechado · somente leitura')),
                ],
              ),
            ),
          ),
        if (!state.activeList!.isClosed)
          MonthlyListCopyCard(
            key: ValueKey('copy-${state.activeList!.id}'),
            houseId: state.activeHouse!.id,
            lists: state.monthlyLists,
            destination: state.activeList!,
            destinationHasItems: state.items.isNotEmpty,
            onCopied: state.refreshItems,
          ),
        Expanded(child: ItemListView()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final house = state.activeHouse;
    final title =
        house?.name ??
        (state.houseLoading
            ? 'Carregando casa'
            : state.houseError != null
            ? 'Casa indisponível'
            : 'Selecione uma casa');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Voltar para as casas',
          onPressed: () => context.go('/casas'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Adicionar item',
            onPressed:
                house == null ||
                    state.activeList == null ||
                    state.activeList!.isClosed
                ? null
                : () => _addItem(context, state),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _body(context, state),
    );
  }
}

class _HouseErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onBack;

  const _HouseErrorState({
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
            Icons.home_work_outlined,
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
