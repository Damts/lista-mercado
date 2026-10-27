import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_mercado/api.dart';
import 'package:lista_mercado/main.dart' show App;
import 'package:lista_mercado/models/house.dart';
import 'package:lista_mercado/models/user.dart';
import 'package:lista_mercado/state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  testWidgets('tocar o card da casa navega para a lista da casa selecionada', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {
            'id': 7,
            'nome': 'Casa carregada pela API',
            'created_at': '2026-10-27T12:00:00.000000Z',
          },
        });
      }
      if (request.url.path == '/api/v1/itens') {
        return _json({
          'data': [],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      return http.Response('{}', 404);
    });
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    final prefs = await SharedPreferences.getInstance();
    final state =
        AppState(
            ApiClient(
              prefs: prefs,
              baseUrl: 'https://api.example.test/api',
              client: client,
            ),
          )
          ..user = User(id: 1, name: 'Morador', email: 'morador@example.test')
          ..houses = [House(id: 7, name: 'Casa teste')]
          ..loading = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const App()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Casa teste'), findsOneWidget);

    await tester.tap(find.text('Casa teste'));
    await tester.pumpAndSettle();

    expect(state.activeHouse?.name, 'Casa carregada pela API');
    expect(find.text('Casa carregada pela API'), findsOneWidget);
    expect(find.text('Sua lista está vazia'), findsOneWidget);
  });
}
