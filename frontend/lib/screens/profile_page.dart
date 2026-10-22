import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        leading: IconButton(
          onPressed: () => context.go('/casas'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Nenhum usuário carregado.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    child: Text(
                      user.name.isEmpty
                          ? '?'
                          : user.name.substring(0, 1).toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Nome'),
                  subtitle: Text(user.name),
                ),
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: const Text('E-mail'),
                  subtitle: Text(user.email),
                ),
              ],
            ),
    );
  }
}
