import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../widgets/item_list_view.dart';

class ListPage extends StatelessWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final house = context.watch<AppState>().activeHouse;
    return Scaffold(
      appBar: AppBar(
        title: Text(house?.name ?? 'Lista'),
        leading: IconButton(
          tooltip: 'Voltar para as casas',
          onPressed: () => context.go('/casas'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: const ItemListView(),
    );
  }
}
