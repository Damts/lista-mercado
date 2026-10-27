import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/item_list_view.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final house = state.activeHouse;
    return Scaffold(
      appBar: AppBar(
        title: Text(house?.name ?? 'Lista'),
        leading: IconButton(
          tooltip: 'Voltar para as casas',
          onPressed: () => context.go('/casas'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Adicionar item',
            onPressed: house == null ? null : () => _addItem(context, state),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: const ItemListView(),
    );
  }
}
