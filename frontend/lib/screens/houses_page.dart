import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';

class HousesPage extends StatefulWidget {
  const HousesPage({super.key});
  @override
  State<HousesPage> createState() => _HousesState();
}

class _HousesState extends State<HousesPage> {
  final code = TextEditingController();
  String? error;

  Future<void> join() async {
    try {
      await context.read<AppState>().join(code.text);
      code.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Você entrou na casa.')));
      }
    } catch (exception) {
      setState(
        () => error = exception is ApiException
            ? exception.message
            : 'Não foi possível entrar.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suas casas'),
        actions: [
          IconButton(onPressed: state.logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.loadHouses,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...state.houses.map(
              (house) => Card(
                child: ListTile(
                  title: Text(house.name),
                  onTap: () {
                    state.selectHouse(house);
                    context.go('/lista');
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
            if (state.houses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Você ainda não participa de nenhuma casa.'),
              ),
            const Divider(),
            Text(
              'Entrar por convite',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Código do convite'),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            FilledButton(onPressed: join, child: const Text('Entrar na casa')),
          ],
        ),
      ),
    );
  }
}
