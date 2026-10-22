import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  void _showError(Object exception) {
    if (!mounted) return;
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

  Future<void> _createHouse() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Criar uma casa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome da casa'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) return;
    try {
      final house = await context.read<AppState>().createHouse(name);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Casa "${house.name}" criada.')));
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _joinHouse() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Entrar em uma casa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Código da casa'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (code == null || code.trim().isEmpty) return;
    try {
      await context.read<AppState>().join(code);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Você entrou na casa.')));
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _createInvite(int houseId) async {
    try {
      final code = await context.read<AppState>().createInvite(houseId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Convite da casa'),
          content: SelectableText(code),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(dialogContext);
              },
              child: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _logout() async {
    Navigator.pop(context);
    final state = context.read<AppState>();
    await state.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      child: Text(
                        (user == null || user.name.isEmpty)
                            ? '?'
                            : user.name.substring(0, 1).toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Visitante',
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user?.email ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Minhas casas'),
                selected: true,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/casas');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Meu perfil'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/perfil');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Configurações'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/configuracoes');
                },
              ),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: _logout,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('Suas casas'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            tooltip: 'Casas',
            onSelected: (value) {
              if (value == 'criar') {
                _createHouse();
              } else {
                _joinHouse();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'criar',
                child: Row(
                  children: const [
                    Icon(Icons.add_home_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Criar uma casa'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'entrar',
                child: Row(
                  children: const [
                    Icon(Icons.login, size: 20),
                    SizedBox(width: 8),
                    Text('Entrar em uma casa'),
                  ],
                ),
              ),
            ],
          ),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1),
                        tooltip: 'Gerar convite',
                        onPressed: () => _createInvite(house.id),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            if (state.houses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Você ainda não participa de nenhuma casa.\n'
                  'Use o + para criar uma casa ou entrar com um código.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
