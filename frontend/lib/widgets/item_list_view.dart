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

class _ItemListViewState extends State<ItemListView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _pendingScroll = ScrollController();
  final _boughtScroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _pendingScroll.addListener(() => _loadWhenNearEnd(false));
    _boughtScroll.addListener(() => _loadWhenNearEnd(true));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pendingScroll.dispose();
    _boughtScroll.dispose();
    super.dispose();
  }

  void _loadWhenNearEnd(bool bought) {
    final scroll = bought ? _boughtScroll : _pendingScroll;
    if (!scroll.hasClients || scroll.position.extentAfter >= 240) return;
    final state = context.read<AppState>();
    if (bought
        ? state.boughtItemsError != null ||
              state.boughtLoading ||
              state.boughtLoadingMore ||
              !state.hasMoreBoughtItems
        : state.itemsError != null ||
              state.itemsLoading ||
              state.itemsLoadingMore ||
              !state.hasMoreItems) {
      return;
    }
    state.loadNextItems(bought: bought);
  }

  void _fillViewport(bool bought) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadWhenNearEnd(bought);
    });
  }

  Future<void> _toggle(Item item) async {
    try {
      await context.read<AppState>().toggle(item);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível atualizar o item. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _edit(Item item) async {
    final state = context.read<AppState>();
    final updated = await showDialog<Item>(
      context: context,
      builder: (_) => EditItemDialog(item: item, onSave: state.updateItem),
    );
    if (updated != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item atualizado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.activeHouse == null) {
      return const Center(child: Text('Selecione uma casa para ver os itens.'));
    }
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Pendentes (${state.items.length})'),
            Tab(text: 'Comprados (${state.boughtItems.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _section(state, bought: false),
              _section(state, bought: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(AppState state, {required bool bought}) {
    final items = bought ? state.boughtItems : state.items;
    final loading = bought ? state.boughtLoading : state.itemsLoading;
    final loadingMore = bought
        ? state.boughtLoadingMore
        : state.itemsLoadingMore;
    final hasMore = bought ? state.hasMoreBoughtItems : state.hasMoreItems;
    final error = bought ? state.boughtItemsError : state.itemsError;
    final scroll = bought ? _boughtScroll : _pendingScroll;
    _fillViewport(bought);
    Future<void> retry() => state.refreshItems();
    if (loading && items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando itens'),
      );
    }
    if (error != null && items.isEmpty) {
      return _InitialError(message: error, onRetry: retry);
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: retry,
        child: ListView(
          key: ValueKey(bought ? 'bought-item-list' : 'pending-item-list'),
          controller: scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 72),
            Icon(
              bought
                  ? Icons.shopping_bag_outlined
                  : Icons.shopping_basket_outlined,
              size: 48,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                bought ? 'Nenhum item comprado' : 'Nenhum item pendente',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                bought
                    ? 'Os itens comprados aparecerão aqui.'
                    : 'Adicione um item para começar.',
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: retry,
      child: ListView.builder(
        key: ValueKey(bought ? 'bought-item-list' : 'pending-item-list'),
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index < items.length) {
            final item = items[index];
            return _ItemCard(
              item: item,
              onToggle: () => _toggle(item),
              onTap: () => _edit(item),
            );
          }
          if (loadingMore) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Carregando mais itens',
                ),
              ),
            );
          }
          if (error != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => state.loadNextItems(bought: bought),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }
          if (!hasMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Você chegou ao fim da lista.')),
            );
          }
          return const SizedBox(height: 16);
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
  String get _priceLabel => item.price == null
      ? 'Preço não informado'
      : 'R\$ ${item.price!.replaceFirst('.', ',')}';
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minVerticalPadding: 12,
      onTap: onTap,
      leading: Checkbox(
        value: item.bought,
        onChanged: (_) => onToggle(),
        semanticLabel:
            'Marcar ${item.name} como ${item.bought ? 'pendente' : 'comprado'}',
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
