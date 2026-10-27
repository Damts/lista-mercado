import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_mercado/api.dart';
import 'package:lista_mercado/models/house.dart';
import 'package:lista_mercado/screens/list_page.dart';
import 'package:lista_mercado/state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _item(int id, {String? name}) => {
  'id': id,
  'nome': name ?? 'Produto $id',
  'quantidade': id,
  'medida': 'un',
  'preco': null,
  'comprado': false,
  'created_at': '2026-10-27T12:00:00.000000Z',
  'updated_at': '2026-10-27T12:00:00.000000Z',
};

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  required bool hasMore,
  String? nextCursor,
}) => {
  'data': items,
  'meta': {'per_page': 20, 'has_more': hasMore, 'next_cursor': nextCursor},
};

void main() {
  testWidgets(
    'editar item da pagina 2 move-o ao topo sem refazer GET nem duplicar',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firstPage = List.generate(20, (index) => _item(20 - index));
      final secondPage = List.generate(20, (index) => _item(40 - index));
      final requestedCursors = <String?>[];
      Map<String, dynamic>? patchBody;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/casas/7') {
          return _json({
            'data': {'id': 7, 'nome': 'Casa de teste'},
          });
        }
        if (request.url.path == '/api/v1/itens' && request.method == 'GET') {
          final cursor = request.url.queryParameters['cursor'];
          requestedCursors.add(cursor);
          if (cursor == null) {
            return _json(
              _page(firstPage, hasMore: true, nextCursor: 'cursor-page-1'),
            );
          }
          if (cursor == 'cursor-page-1') {
            return _json(
              _page(secondPage, hasMore: true, nextCursor: 'cursor-page-2'),
            );
          }
          return _json(_page([], hasMore: false));
        }
        if (request.url.path == '/api/v1/itens/40' &&
            request.method == 'PATCH') {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({
            'data': {
              ..._item(40, name: 'Produto 40 editado'),
              'updated_at': '2026-10-27T12:01:00.000000Z',
            },
          });
        }
        return _json({'message': 'Não encontrado'}, status: 404);
      });
      SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
      final prefs = await SharedPreferences.getInstance();
      final state = AppState(
        ApiClient(
          prefs: prefs,
          baseUrl: 'https://api.example.test/api',
          client: client,
        ),
      );
      await state.selectHouse(House(id: 7, name: 'Casa de teste'));
      await state.loadNextItems();
      expect(state.items, hasLength(40));
      expect(state.nextItemsCursor, 'cursor-page-2');

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(home: ListPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Produto 40'),
        250,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Produto 40'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Produto 40 editado',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(patchBody, {
        'nome': 'Produto 40 editado',
        'quantidade': 40,
        'medida': 'un',
        'preco': null,
        'comprado': false,
      });
      expect(state.items, hasLength(40));
      expect(state.items.first.id, 40);
      expect(state.items.first.name, 'Produto 40 editado');
      expect(state.items.where((item) => item.id == 40), hasLength(1));
      expect(state.nextItemsCursor, 'cursor-page-2');
      expect(state.hasMoreItems, isTrue);
      expect(requestedCursors, [null, 'cursor-page-1']);
      expect(find.text('Produto 40 editado'), findsOneWidget);
    },
  );
}
