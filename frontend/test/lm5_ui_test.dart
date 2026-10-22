import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/api.dart';
import 'package:lista_mercado/models/house.dart';
import 'package:lista_mercado/screens/houses_page.dart';
import 'package:lista_mercado/screens/login_page.dart';
import 'package:lista_mercado/state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AppState(ApiClient(prefs: prefs));
}

Widget _wrap(AppState state, Widget child) => ChangeNotifierProvider.value(
  value: state,
  child: MaterialApp(home: child),
);

void main() {
  testWidgets('cadastro exige confirmação de senha', (tester) async {
    final state = await _state();
    await tester.pumpWidget(_wrap(state, const LoginPage()));
    await tester.tap(find.text('Criar uma conta'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar senha'), findsOneWidget);
  });

  testWidgets('senhas diferentes bloqueiam o cadastro', (tester) async {
    final state = await _state();
    await tester.pumpWidget(_wrap(state, const LoginPage()));
    await tester.tap(find.text('Criar uma conta'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Damts');
    await tester.enterText(fields.at(1), 'damts@example.com');
    await tester.enterText(fields.at(2), 'senha12345');
    await tester.enterText(fields.at(3), 'senha99999');
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text('As senhas não conferem'), findsOneWidget);
  });

  testWidgets('casa mostra botão de gerar convite', (tester) async {
    final state = await _state();
    state.houses = [House(id: 1, name: 'Casa Teste')];
    await tester.pumpWidget(_wrap(state, const HousesPage()));

    expect(find.text('Casa Teste'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
  });

  testWidgets('casas: drawer com atalhos e botão + no topo', (tester) async {
    final state = await _state();
    await tester.pumpWidget(_wrap(state, const HousesPage()));
    expect(find.byIcon(Icons.add), findsOneWidget);

    tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Minhas casas'), findsOneWidget);
    expect(find.text('Meu perfil'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });
}
