import 'dart:async';
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
  required String measure,
  String? price,
  bool bought = false,
  required String updatedAt,
}) => {
  'id': id,
  'nome': name,
  'quantidade': quantity,
  'medida': measure,
  'preco': price,
  'comprado': bought,
  'created_at': '2026-10-22T12:00:00.000000Z',
  'updated_at': updatedAt,
};

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
  'data': items,
  'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
};

Widget _wrap(AppState state) => ChangeNotifierProvider.value(
  value: state,
  child: const MaterialApp(home: ListPage()),
);

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

MockClient _client(List<Map<String, dynamic>> items) =>
    MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa de teste'},
        });
      }
      if (request.url.path == '/api/v1/itens') {
        return _json(_page(items));
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });

void main() {
  testWidgets('card mostra quantidade junto da medida do item', (tester) async {
    final state = await _state(
      _client([
        _item(
          id: 1,
          name: 'Farinha',
          quantity: 2,
          measure: 'kg',
          price: '4.20',
          updatedAt: '2026-10-27T12:01:00.000000Z',
        ),
      ]),
    );
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 kg'), findsOneWidget);
  });

  testWidgets('tocar no card abre o dialog de edicao do item', (tester) async {
    final state = await _state(
      _client([
        _item(
          id: 1,
          name: 'Farinha',
          quantity: 2,
          measure: 'kg',
          price: '4.20',
          updatedAt: '2026-10-27T12:01:00.000000Z',
        ),
      ]),
    );
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Farinha'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller
          ?.text,
      '4,20',
    );
  });

  testWidgets('edicao valida, envia os cinco campos e move sem duplicar', (
    tester,
  ) async {
    Map<String, dynamic>? patchBody;
    String? houseIdHeader;
    final patchResponse = Completer<http.Response>();
    final initialItems = [
      _item(
        id: 3,
        name: 'Arroz',
        quantity: 2,
        measure: 'kg',
        price: '5.00',
        updatedAt: '2026-10-27T12:02:00.000000Z',
      ),
      _item(
        id: 2,
        name: 'Azeite',
        quantity: 1,
        measure: 'un',
        updatedAt: '2026-10-27T12:01:00.000000Z',
      ),
    ];
    final updatedItem = _item(
      id: 2,
      name: 'Azeite extra',
      quantity: 500,
      measure: 'ml',
      price: '0.10',
      bought: true,
      updatedAt: '2026-10-27T12:02:00.000000Z',
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa de teste'},
        });
      }
      if (request.url.path == '/api/v1/itens' && request.method == 'GET') {
        return _json(_page(initialItems));
      }
      if (request.url.path == '/api/v1/itens/2' && request.method == 'PATCH') {
        patchBody = jsonDecode(request.body) as Map<String, dynamic>;
        houseIdHeader = request.headers['x-casa-id'];
        return patchResponse.future;
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Azeite'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller?.text,
      'Azeite',
    );
    expect(tester.widget<TextFormField>(fields.at(1)).controller?.text, '1');
    expect(tester.widget<TextFormField>(fields.at(2)).controller?.text, '');
    expect(find.text('un'), findsOneWidget);
    final dropdownField = find.byKey(const ValueKey('item-measure-dropdown'));
    final dropdownButton = find.descendant(
      of: dropdownField,
      matching: find.byType(DropdownButton<String>),
    );
    expect(
      tester
          .widget<DropdownButton<String>>(dropdownButton)
          .items!
          .map((option) => option.value)
          .toList(),
      ['un', 'g', 'kg', 'ml', 'l'],
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('item-bought-checkbox')),
          )
          .value,
      isFalse,
    );

    await tester.enterText(fields.at(0), '   ');
    await tester.enterText(fields.at(1), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome do item.'), findsOneWidget);
    expect(find.text('Informe uma quantidade a partir de 1.'), findsOneWidget);
    expect(patchBody, isNull);

    await tester.enterText(fields.at(0), 'Azeite extra');
    await tester.enterText(fields.at(1), '500');
    await tester.enterText(fields.at(2), '0,10');
    await tester.tap(find.byKey(const ValueKey('item-measure-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('item-bought-checkbox')));
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();
    expect(find.text('Salvando…'), findsOneWidget);
    expect(patchBody, isNotNull);
    patchResponse.complete(_json({'data': updatedItem}));
    await tester.pumpAndSettle();

    expect(patchBody, {
      'nome': 'Azeite extra',
      'quantidade': 500,
      'medida': 'ml',
      'preco': '0.10',
      'comprado': true,
    });
    expect(houseIdHeader, '7');
    expect(find.text('Item atualizado.'), findsOneWidget);
    expect(state.items.map((item) => item.id).toList(), [2, 3]);
    expect(state.items.where((item) => item.id == 2), hasLength(1));
    expect(state.items.first.name, 'Azeite extra');
    expect(state.items.first.quantity, 500);
    expect(state.items.first.measure, 'ml');
    expect(state.items.first.price, '0.10');
    expect(state.items.first.bought, isTrue);
    expect(find.textContaining('500 ml'), findsOneWidget);
  });

  testWidgets('erro 422 mantém dialog aberto e preserva o item', (
    tester,
  ) async {
    var patchRequests = 0;
    final original = _item(
      id: 1,
      name: 'Farinha',
      quantity: 2,
      measure: 'kg',
      price: '4.20',
      updatedAt: '2026-10-27T12:01:00.000000Z',
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa de teste'},
        });
      }
      if (request.url.path == '/api/v1/itens' && request.method == 'GET') {
        return _json(_page([original]));
      }
      if (request.url.path == '/api/v1/itens/1' && request.method == 'PATCH') {
        patchRequests++;
        return _json({
          'message': 'Validação falhou.',
          'errors': {
            'medida': ['Medida não aceita.'],
          },
        }, status: 422);
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Farinha'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(patchRequests, 1);
    expect(find.text('Medida não aceita.'), findsOneWidget);
    expect(find.text('Editar item'), findsOneWidget);
    expect(state.items.single.name, 'Farinha');
    expect(find.text('Item atualizado.'), findsNothing);
  });

  testWidgets('cancelar edicao nao envia PATCH nem altera o item', (
    tester,
  ) async {
    var patchRequests = 0;
    final original = _item(
      id: 1,
      name: 'Farinha',
      quantity: 2,
      measure: 'kg',
      updatedAt: '2026-10-27T12:01:00.000000Z',
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa de teste'},
        });
      }
      if (request.url.path == '/api/v1/itens' && request.method == 'GET') {
        return _json(_page([original]));
      }
      if (request.method == 'PATCH') patchRequests++;
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Farinha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(patchRequests, 0);
    expect(state.items.single.name, 'Farinha');
    expect(find.text('Editar item'), findsNothing);
  });

  test(
    'toggle tambem usa item atualizado e reordena sem duplicar ids',
    () async {
      var patchBody = <String, dynamic>{};
      final first = _item(
        id: 1,
        name: 'Arroz',
        quantity: 2,
        measure: 'kg',
        updatedAt: '2026-10-27T12:02:00.000000Z',
      );
      final second = _item(
        id: 2,
        name: 'Leite',
        quantity: 1,
        measure: 'l',
        updatedAt: '2026-10-27T12:01:00.000000Z',
      );
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/casas/7') {
          return _json({
            'data': {'id': 7, 'nome': 'Casa de teste'},
          });
        }
        if (request.url.path == '/api/v1/itens' && request.method == 'GET') {
          return _json(_page([first, second]));
        }
        if (request.url.path == '/api/v1/itens/2' &&
            request.method == 'PATCH') {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({
            'data': _item(
              id: 2,
              name: 'Leite',
              quantity: 1,
              measure: 'l',
              bought: true,
              updatedAt: '2026-10-27T12:03:00.000000Z',
            ),
          });
        }
        return _json({'message': 'Não encontrado'}, status: 404);
      });
      final state = await _state(client);
      await state.selectHouse(House(id: 7, name: 'Casa de teste'));

      await state.toggle(state.items.last);

      expect(patchBody, {'comprado': true});
      expect(state.items.map((item) => item.id).toList(), [2, 1]);
      expect(state.items.where((item) => item.id == 2), hasLength(1));
      expect(state.items.first.bought, isTrue);
    },
  );

  testWidgets('preco pode ser apagado sem virar zero', (tester) async {
    Map<String, dynamic>? patchBody;
    final original = _item(
      id: 4,
      name: 'Café',
      quantity: 2,
      measure: 'kg',
      price: '5.50',
      updatedAt: '2026-10-27T12:01:00.000000Z',
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa de teste'},
        });
      }
      if (request.url.path == '/api/v1/itens' && request.method == 'GET') {
        return _json(_page([original]));
      }
      if (request.url.path == '/api/v1/itens/4' && request.method == 'PATCH') {
        patchBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({
          'data': _item(
            id: 4,
            name: 'Café',
            quantity: 2,
            measure: 'kg',
            updatedAt: '2026-10-27T12:02:00.000000Z',
          ),
        });
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Café'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(patchBody?['preco'], isNull);
    expect(state.items.single.price, isNull);
    expect(find.textContaining('2 kg · Preço não informado'), findsOneWidget);
  });

  testWidgets('404 no PATCH deixa dialog aberto com mensagem de erro', (
    tester,
  ) async {
    final original = _item(
      id: 5,
      name: 'Feijão',
      quantity: 1,
      measure: 'un',
      updatedAt: '2026-10-27T12:01:00.000000Z',
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa de teste'},
        });
      }
      if (request.url.path == '/api/v1/itens' && request.method == 'GET') {
        return _json(_page([original]));
      }
      if (request.url.path == '/api/v1/itens/5' && request.method == 'PATCH') {
        return _json({
          'message': 'Item não encontrado nesta casa.',
          'error_code': 'not_found',
        }, status: 404);
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feijão'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);
    expect(find.text('Item não encontrado nesta casa.'), findsOneWidget);
    expect(state.items.single.name, 'Feijão');
    expect(find.text('Item atualizado.'), findsNothing);
  });
}
