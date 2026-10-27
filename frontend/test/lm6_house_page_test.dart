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

Map<String, dynamic> _item({
  required int id,
  required String name,
  required int quantity,
  Object? price,
}) => {
  'id': id,
  'nome': name,
  'quantidade': quantity,
  'preco': price,
  'comprado': false,
  'created_at': '2026-10-22T12:00:00.000000Z',
  'updated_at': '2026-10-22T12:00:00.000000Z',
};

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
  'data': items,
  'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
};

Widget _wrap(AppState state) => ChangeNotifierProvider.value(
  value: state,
  child: const MaterialApp(home: ListPage()),
);

void main() {
  testWidgets(
    'casa usa nome do contrato e cards mostram nome, quantidade e preço',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/casa-atual') {
          return _json({
            'data': {'id': 12, 'nome': 'Casa do contrato'},
          });
        }
        if (request.url.path == '/api/v1/itens') {
          return _json(
            _page([
              _item(id: 1, name: 'Arroz', quantity: 2, price: '0.10'),
              _item(id: 2, name: 'Sabão', quantity: 1),
            ]),
          );
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
      await state.selectHouse(House(id: 12, name: 'Nome antigo'));

      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();

      expect(find.text('Casa do contrato'), findsOneWidget);
      expect(find.text('Arroz'), findsOneWidget);
      expect(find.textContaining(r'R$ 0,10'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Quantidade: 1 · Preço não informado'),
        200,
      );
      expect(find.text('Quantidade: 1 · Preço não informado'), findsOneWidget);
      expect(find.byTooltip('Adicionar item'), findsOneWidget);
    },
  );

  testWidgets('botão adicionar valida campos e envia preço opcional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? submittedBody;
    String? houseHeader;
    var itemReads = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casa-atual') {
        return _json({
          'data': {'id': 12, 'nome': 'Casa'},
        });
      }
      if (request.url.path == '/api/v1/itens' && request.method == 'POST') {
        submittedBody = jsonDecode(request.body) as Map<String, dynamic>;
        houseHeader = request.headers['x-casa-id'];
        return _json({
          'data': _item(id: 9, name: 'Feijão', quantity: 3),
        }, status: 201);
      }
      if (request.url.path == '/api/v1/itens' && request.method == 'GET') {
        itemReads++;
        final items = itemReads == 1
            ? <Map<String, dynamic>>[]
            : [_item(id: 9, name: 'Feijão', quantity: 3)];
        return _json(_page(items));
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
    await state.selectHouse(House(id: 12, name: 'Casa'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Adicionar item'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome do item.'), findsOneWidget);
    expect(find.text('Informe uma quantidade a partir de 1.'), findsOneWidget);
    expect(submittedBody, isNull);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Feijão');
    await tester.enterText(fields.at(1), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(submittedBody, {'nome': 'Feijão', 'quantidade': 3, 'preco': null});
    expect(houseHeader, '12');
    expect(find.text('Item adicionado.'), findsOneWidget);
    expect(find.text('Feijão'), findsOneWidget);

    await tester.tap(find.byTooltip('Adicionar item'));
    await tester.pumpAndSettle();
    final decimalFields = find.byType(TextFormField);
    await tester.enterText(decimalFields.at(0), 'Azeite');
    await tester.enterText(decimalFields.at(1), '1');
    await tester.enterText(decimalFields.at(2), '0,10');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();
    expect(submittedBody, {'nome': 'Azeite', 'quantidade': 1, 'preco': '0.10'});
  });
}
