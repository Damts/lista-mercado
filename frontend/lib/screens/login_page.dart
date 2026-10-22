import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';

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
  final confirm = TextEditingController();
  bool register = false, busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final state = context.read<AppState>();
      if (register) {
        await state.register(
          name.text,
          email.text,
          password.text,
          confirm.text,
        );
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

  void toggleMode() {
    setState(() {
      register = !register;
      error = null;
      confirm.clear();
    });
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
                  if (register)
                    TextFormField(
                      controller: confirm,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                      ),
                      validator: (value) => value == password.text
                          ? null
                          : 'As senhas não conferem',
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
                    onPressed: busy ? null : toggleMode,
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
