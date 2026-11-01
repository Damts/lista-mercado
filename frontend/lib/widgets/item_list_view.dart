import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../state.dart';
import 'edit_item_dialog.dart';

class ItemListView extends StatefulWidget {
  const ItemListView({super.key});

  @override
  State<ItemListView> createState() => _ItemListViewState();
}

class _ItemListViewState extends State<ItemListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadWhenNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadWhenNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadWhenNearEnd() {
    if (!_scrollController.hasClients) return;
    final state = context.read<AppState>();
    if (state.itemsError != null ||
        state.itemsLoading ||
        state.itemsLoadingMore ||
        !state.hasMoreItems) {
      return;
    }
    if (_scrollController.position.extentAfter < 240) {
      state.loadNextItems();
    }
  }

  void _scheduleFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadWhenNearEnd();
    });
  }

  Future<void> _toggle(Item item) async {
    try {
      await context.read<AppState>().toggle(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar o item. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> _edit(Item item) async {
    final state = context.read<AppState>();
    final updated = await showDialog<Item>(
      context: context,
      builder: (_) => EditItemDialog(item: item, onSave: state.updateItem),
    );
    if (updated != null && mounted) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item atualizado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _scheduleFillViewport();

    if (state.activeHouse == null) {
      return const Center(child: Text('Selecione uma casa para ver os itens.'));
    }
    if (state.itemsLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando itens'),
      );
    }
    if (state.itemsError != null && state.items.isEmpty) {
      return _InitialError(
        message: state.itemsError!,
        onRetry: state.refreshItems,
      );
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: state.refreshItems,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 96),
            Icon(Icons.shopping_basket_outlined, size: 48),
            SizedBox(height: 12),
            Center(
              child: Text(
                'Sua lista está vazia',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 4),
            Center(child: Text('Adicione um item para começar.')),
            SizedBox(height: 8),
            Center(child: Text('Você chegou ao fim da lista.')),
            SizedBox(height: 32),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: state.refreshItems,
      child: ListView.builder(
        key: const ValueKey('item-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            final item = state.items[index];
            return _ItemCard(
              item: item,
              onToggle: () => _toggle(item),
              onTap: () => _edit(item),
            );
          }
          return _PageFooter(
            state: state,
            onRetry: state.hasMoreItems
                ? state.loadNextItems
                : state.refreshItems,
          );
        },
      ),
    );
  }
}

class _InitialError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _InitialError({required this.message, required this.onRetry});

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
        ],
      ),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _ItemCard({
    required this.item,
    required this.onToggle,
    required this.onTap,
  });

  String get _priceLabel {
    final price = item.price;
    if (price == null) return 'Preço não informado';
    return 'R\$ ${price.replaceFirst('.', ',')}';
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minVerticalPadding: 12,
      onTap: onTap,
      leading: Checkbox(
        value: item.bought,
        onChanged: (_) => onToggle(),
        semanticLabel: 'Marcar ${item.name} como comprado',
      ),
      title: Text(
        item.name,
        style: item.bought
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: Text('${item.quantity} ${item.measure} · $_priceLabel'),
    ),
  );
}

class _PageFooter extends StatelessWidget {
  final AppState state;
  final Future<void> Function() onRetry;

  const _PageFooter({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (state.itemsLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Carregando mais itens',
          ),
        ),
      );
    }
    if (state.itemsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(state.itemsError!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (!state.hasMoreItems) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Você chegou ao fim da lista.')),
      );
    }
    return const SizedBox(height: 16);
  }
}
