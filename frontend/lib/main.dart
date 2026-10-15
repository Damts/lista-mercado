import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models/item.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(ApiClient(prefs: prefs));
  await state.bootstrap();
  runApp(ChangeNotifierProvider.value(value: state, child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final router = GoRouter(
      initialLocation: state.authenticated ? '/casas' : '/login',
      redirect: (_, location) {
        if (state.loading) return null;
        if (!state.authenticated && location.matchedLocation != '/login') {
          return '/login';
        }
        if (state.authenticated && location.matchedLocation == '/login') {
          return '/casas';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(path: '/casas', builder: (_, _) => const HousesPage()),
        GoRoute(path: '/lista', builder: (_, _) => const ListPage()),
      ],
    );
    return MaterialApp.router(
      title: 'Lista Mercado',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false, busy = false;
  String? error;

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final state = context.read<AppState>();
      if (register) {
        await state.register(name.text, email.text, password.text);
      } else {
        await state.login(email.text, password.text);
      }
      if (mounted) context.go('/casas');
    } catch (exception) {
      setState(
        () => error = exception is ApiException
            ? exception.message
            : 'Falha inesperada.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lista Mercado',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  if (register)
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Informe seu nome' : null,
                    ),
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.contains('@')
                        ? null
                        : 'Informe um e-mail válido',
                  ),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    validator: (value) =>
                        value!.length < 8 ? 'Mínimo de 8 caracteres' : null,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Aguarde...'
                          : register
                          ? 'Criar conta'
                          : 'Entrar',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => register = !register),
                    child: Text(
                      register ? 'Já tenho conta' : 'Criar uma conta',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
