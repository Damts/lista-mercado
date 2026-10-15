import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models/item.dart';
import '../state.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});
  @override
  State<ListPage> createState() => _ListState();
}

class _ListState extends State<ListPage> {
  final addController = TextEditingController();
  final editController = TextEditingController();

  void showError(Object exception) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exception is ApiException
              ? exception.message
              : 'Não foi possível concluir.',
        ),
      ),
    );
  }

  Future<void> addItem() async {
    if (addController.text.trim().isEmpty) return;
    try {
      await context.read<AppState>().add(addController.text);
      addController.clear();
    } catch (exception) {
      showError(exception);
    }
  }

  Future<void> editItem(Item item) async {
    editController.text = item.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar item'),
        content: TextField(controller: editController, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (confirmed == true && editController.text.trim().isNotEmpty) {
      try {
        if (!mounted) return;
        final state = context.read<AppState>();
        await state.edit(item, editController.text);
        if (!mounted) return;
      } catch (exception) {
        showError(exception);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(state.activeHouse?.name ?? 'Lista'),
        leading: IconButton(
          onPressed: () => context.go('/casas'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshItems,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addController,
                    onSubmitted: (_) => addItem(),
                    decoration: const InputDecoration(
                      labelText: 'Adicionar item',
                    ),
                  ),
                ),
                IconButton(onPressed: addItem, icon: const Icon(Icons.add)),
              ],
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ...state.items.map(
              (item) => ListTile(
                leading: Checkbox(
                  value: item.checked,
                  onChanged: (_) => state.toggle(item),
                ),
                title: Text(
                  item.name,
                  style: item.checked
                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                      : null,
                ),
                onTap: () => editItem(item),
                trailing: IconButton(
                  onPressed: () => state.remove(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
