import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          onPressed: () => context.go('/casas'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Conta'),
          ),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('E-mail'),
            subtitle: Text(user?.email ?? '—'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Aplicativo'),
          ),
          const ListTile(
            leading: Icon(Icons.tag),
            title: Text('Versão'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.dns_outlined),
            title: Text('Servidor'),
            subtitle: Text(AppConfig.backendUrl),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Mais configurações (tema, notificações, privacidade) entram nas próximas tarefas.',
            ),
          ),
        ],
      ),
    );
  }
}
