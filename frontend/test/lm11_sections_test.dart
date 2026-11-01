import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_mercado/api.dart';
import 'package:lista_mercado/models/house.dart';
import 'package:lista_mercado/state.dart';
import 'package:lista_mercado/widgets/item_list_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
);
Map<String, Object?> item(int id, bool bought) => {
  'id': id,
  'nome': 'Produto $id',
  'quantidade': 1,
  'medida': 'un',
  'preco': null,
  'comprado': bought,
  'created_at': '2026-10-31T12:00:00Z',
  'updated_at': '2026-10-31T12:00:00Z',
};
Map<String, Object?> page(
  List<Map<String, Object?>> items, {
  String? cursor,
  required bool more,
}) => {
  'data': items,
  'meta': {'per_page': 20, 'has_more': more, 'next_cursor': cursor},
};

void main() {
  testWidgets(
    'seções têm filtros e cursores independentes; comprado vazio não quebra layout',
    (tester) async {
      final received = <String, String?>{};
      final httpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/casas/7') {
          return jsonResponse({
            'data': {'id': 7, 'nome': 'Casa'},
          });
        }
        final filter = request.url.queryParameters['comprado'];
        final cursor = request.url.queryParameters['cursor'];
        received['$filter:${cursor ?? 'first'}'] = cursor;
        if (filter == 'false') {
          return jsonResponse(
            cursor == null
                ? page([item(1, false)], cursor: 'pending-next', more: true)
                : page([item(2, false)], more: false),
          );
        }
        return jsonResponse(page([], more: false));
      });
      SharedPreferences.setMockInitialValues({'auth_token': 'test'});
      final prefs = await SharedPreferences.getInstance();
      final state = AppState(
        ApiClient(
          prefs: prefs,
          baseUrl: 'https://test/api',
          client: httpClient,
        ),
      );
      await state.selectHouse(House(id: 7, name: 'Casa'));
      expect(state.items, hasLength(1));
      expect(state.boughtItems, isEmpty);
      await state.loadNextItems();
      expect(received['false:pending-next'], 'pending-next');
      expect(state.items.map((e) => e.id), [1, 2]);
      expect(state.boughtItems, isEmpty);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(home: Scaffold(body: ItemListView())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pendentes (2)'), findsOneWidget);
      expect(find.text('Comprados (0)'), findsOneWidget);
      await tester.tap(find.text('Comprados (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum item comprado'), findsOneWidget);
    },
  );

  test('cada seção mantém o cursor da sua própria consulta filtrada', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return jsonResponse({
          'data': {'id': 7, 'nome': 'Casa'},
        });
      }
      final bought = request.url.queryParameters['comprado'] == 'true';
      final cursor = request.url.queryParameters['cursor'];
      requested.add('${bought ? 'true' : 'false'}:${cursor ?? 'initial'}');
      if (cursor == null && bought) {
        return jsonResponse(
          page([item(3, true)], cursor: 'bought-cursor', more: true),
        );
      }
      if (cursor == null) {
        return jsonResponse(
          page([item(1, false)], cursor: 'pending-cursor', more: true),
        );
      }
      if (bought) return jsonResponse(page([item(4, true)], more: false));
      return jsonResponse(page([item(2, false)], more: false));
    });
    SharedPreferences.setMockInitialValues({'auth_token': 'test'});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(
      ApiClient(prefs: prefs, baseUrl: 'https://test/api', client: client),
    );
    await state.selectHouse(House(id: 7, name: 'Casa'));
    await state.loadNextItems(bought: true);
    await state.loadNextItems();
    expect(
      requested,
      containsAll(['true:bought-cursor', 'false:pending-cursor']),
    );
    expect(state.boughtItems.map((item) => item.id), [3, 4]);
    expect(state.items.map((item) => item.id), [1, 2]);
    expect(state.hasMoreBoughtItems, isFalse);
    expect(state.hasMoreItems, isFalse);
  });
}
