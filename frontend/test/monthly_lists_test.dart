import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_mercado/api.dart';
import 'package:lista_mercado/models/house.dart';
import 'package:lista_mercado/models/monthly_list.dart';
import 'package:lista_mercado/screens/list_page.dart';
import 'package:lista_mercado/state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _item(int id, String name) => {
  'id': id,
  'nome': name,
  'quantidade': 1,
  'medida': 'un',
  'preco': '1.25',
  'comprado': false,
  'created_at': '2026-10-20T12:00:00.000000Z',
  'updated_at': '2026-10-20T12:00:00.000000Z',
};

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
  'data': items,
  'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
};

Map<String, dynamic> _list({
  required int id,
  required int year,
  required int month,
  String? closedAt,
}) => {
  'id': id,
  'casa_id': 7,
  'ano': year,
  'mes': month,
  'fechado_em': closedAt,
  'created_at': '2026-10-01T00:00:00.000000Z',
  'updated_at': '2026-10-01T00:00:00.000000Z',
};

Future<AppState> _state(MockClient client) async {
  SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
  final prefs = await SharedPreferences.getInstance();
  return AppState(
    ApiClient(
      prefs: prefs,
      baseUrl: 'https://api.example.test/api',
      client: client,
    ),
  );
}

Widget _wrap(AppState state) => ChangeNotifierProvider.value(
  value: state,
  child: const MaterialApp(home: ListPage()),
);

void main() {
  test(
    'mês é apresentado no locale pt-BR e fechado_em determina somente leitura',
    () {
      final current = MonthlyList.fromJson(
        _list(id: 10, year: 2026, month: 11),
      );
      final closed = MonthlyList.fromJson(
        _list(id: 9, year: 2026, month: 10, closedAt: '2026-11-01T00:00:00Z'),
      );
      expect(current.label, 'Novembro de 2026');
      expect(current.isClosed, isFalse);
      expect(closed.label, 'Outubro de 2026');
      expect(closed.isClosed, isTrue);
    },
  );

  testWidgets(
    'seleciona mês corrente; mês fechado mantém leitura e bloqueia edição',
    (tester) async {
      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/api/v1/casas/7') {
          return _json({
            'data': {'id': 7, 'nome': 'Casa de teste'},
          });
        }
        if (request.url.path == '/api/v1/casas/7/listas') {
          expect(request.headers['x-casa-id'], '7');
          return _json({
            'data': [
              _list(id: 10, year: 2026, month: 11),
              _list(
                id: 9,
                year: 2026,
                month: 10,
                closedAt: '2026-11-01T00:00:00Z',
              ),
            ],
          });
        }
        if (request.url.path == '/api/v1/listas/10/itens') {
          expect(request.headers['x-casa-id'], '7');
          return _json(_page([_item(100, 'Leite atual')]));
        }
        if (request.url.path == '/api/v1/listas/9/itens') {
          expect(request.headers['x-casa-id'], '7');
          return _json(_page([_item(99, 'Arroz histórico')]));
        }
        return _json({'message': 'Não encontrado'}, status: 404);
      });
      final state = await _state(client);
      await state.selectHouse(House(id: 7, name: 'Casa'));
      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();

      expect(find.text('Leite atual'), findsOneWidget);
      expect(find.text('Novembro de 2026'), findsOneWidget);
      expect(state.activeList?.id, 10);
      expect(requestedPaths, contains('/api/v1/listas/10/itens'));

      await tester.tap(find.byType(DropdownButtonFormField<MonthlyList>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outubro de 2026 · Fechado').last);
      await tester.pumpAndSettle();

      expect(state.activeList?.id, 9);
      expect(find.text('Arroz histórico'), findsOneWidget);
      expect(find.text('Leite atual'), findsNothing);
      expect(find.text('Mês fechado · somente leitura'), findsOneWidget);
      expect(find.text('Outubro de 2026 · Fechado'), findsOneWidget);
      final addButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Adicionar item'),
          matching: find.byType(IconButton),
        ),
      );
      expect(addButton.onPressed, isNull);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(checkbox.onChanged, isNull);
      expect(requestedPaths, contains('/api/v1/listas/9/itens'));

      await expectLater(
        state.toggle(state.items.single),
        throwsA(
          isA<ApiException>().having(
            (error) => error.errorCode,
            'errorCode',
            'lista_fechada',
          ),
        ),
      );
    },
  );

  testWidgets(
    '409 lista_fechada reconcilia a lista e a interface vira leitura',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/casas/7') {
          return _json({
            'data': {'id': 7, 'nome': 'Casa'},
          });
        }
        if (request.url.path == '/api/v1/casas/7/listas') {
          return _json({
            'data': [_list(id: 10, year: 2026, month: 11)],
          });
        }
        if (request.url.path == '/api/v1/listas/10/itens') {
          return _json(_page([_item(100, 'Feijão')]));
        }
        if (request.url.path == '/api/v1/itens/100' &&
            request.method == 'PATCH') {
          expect(request.headers['x-casa-id'], '7');
          return _json({
            'message': 'Lista fechada.',
            'error_code': 'lista_fechada',
          }, status: 409);
        }
        return _json({'message': 'Não encontrado'}, status: 404);
      });
      final state = await _state(client);
      await state.selectHouse(House(id: 7, name: 'Casa'));
      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(state.activeList?.isClosed, isTrue);
      expect(find.text('Mês fechado · somente leitura'), findsOneWidget);
      expect(find.textContaining('acabou de ser fechado'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
        isNull,
      );
    },
  );

  testWidgets('erro ao buscar meses oferece retry e carrega mês corrente', (
    tester,
  ) async {
    var listRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa'},
        });
      }
      if (request.url.path == '/api/v1/casas/7/listas') {
        listRequests++;
        if (listRequests == 1) {
          return _json({'message': 'Servidor indisponível'}, status: 503);
        }
        return _json({
          'data': [_list(id: 10, year: 2026, month: 11)],
        });
      }
      if (request.url.path == '/api/v1/listas/10/itens') {
        return _json(_page([]));
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Servidor indisponível'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(listRequests, 2);
    expect(state.activeList?.id, 10);
    expect(find.text('Novembro de 2026'), findsOneWidget);
    expect(find.text('Sua lista está vazia'), findsOneWidget);
  });
}
