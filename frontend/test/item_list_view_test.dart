import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_mercado/api.dart';
import 'package:lista_mercado/models/house.dart';
import 'package:lista_mercado/models/item.dart';
import 'package:lista_mercado/state.dart';
import 'package:lista_mercado/widgets/item_list_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _item(int id) => {
  'id': id,
  'nome': 'Item $id',
  'quantidade': id % 4 + 1,
  'medida': 'un',
  'preco': id.isEven ? '12.50' : null,
  'comprado': false,
  'created_at': '2026-10-22T12:00:00.000000Z',
  'updated_at': '2026-10-22T12:00:00.000000Z',
};

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  required bool hasMore,
  String? nextCursor,
}) => {
  'data': items,
  'meta': {'per_page': 20, 'has_more': hasMore, 'next_cursor': nextCursor},
};

Widget _wrap(AppState state) => ChangeNotifierProvider.value(
  value: state,
  child: const MaterialApp(home: Scaffold(body: ItemListView())),
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

http.Response? _commonResponse(http.Request request) {
  if (request.url.path == '/api/v1/casas/7') {
    return _json({
      'data': {'id': 7, 'nome': 'Casa de teste'},
    });
  }
  return null;
}

void main() {
  test('preço decimal mantém a representação original em string', () {
    final item = Item.fromJson({..._item(1), 'preco': '0.10'});
    expect(item.price, '0.10');
  });

  testWidgets('rolagem carrega a próxima página uma vez e encerra no fim', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var cursorRequests = 0;
    final client = MockClient((request) async {
      final common = _commonResponse(request);
      if (common != null) return common;
      if (request.url.path == '/api/v1/itens' &&
          request.url.queryParameters.isEmpty) {
        return _json(
          _page(
            List.generate(20, (index) => _item(index + 1)),
            hasMore: true,
            nextCursor: 'opaque-cursor-1',
          ),
        );
      }
      if (request.url.path == '/api/v1/itens') {
        expect(request.url.queryParameters['cursor'], 'opaque-cursor-1');
        expect(request.headers['x-casa-id'], '7');
        cursorRequests++;
        return _json(_page([_item(21), _item(22)], hasMore: false));
      }
      return _json({'message': 'Not found'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(state.items, hasLength(22));
    expect(state.items.map((item) => item.id).toSet(), hasLength(22));
    expect(cursorRequests, 1);
    expect(state.hasMoreItems, isFalse);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Você chegou ao fim da lista.'), findsOneWidget);
  });

  testWidgets('erro na próxima página mantém itens e permite tentar de novo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var cursorRequests = 0;
    final client = MockClient((request) async {
      final common = _commonResponse(request);
      if (common != null) return common;
      if (request.url.path == '/api/v1/itens' &&
          request.url.queryParameters.isEmpty) {
        return _json(
          _page(
            List.generate(20, (index) => _item(index + 1)),
            hasMore: true,
            nextCursor: 'opaque-cursor-1',
          ),
        );
      }
      cursorRequests++;
      if (cursorRequests == 1) {
        return _json({'message': 'Falha temporária'}, status: 503);
      }
      return _json(_page([_item(21)], hasMore: false));
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(state.items, hasLength(20));
    expect(state.items.first.id, 1);
    expect(find.text('Falha temporária'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(state.items, hasLength(21));
    expect(state.itemsError, isNull);
    expect(cursorRequests, 2);
    expect(find.text('Item 21'), findsOneWidget);
  });

  testWidgets('vazio, erro inicial e loading têm estados explícitos', (
    tester,
  ) async {
    final client = MockClient((request) async {
      final common = _commonResponse(request);
      if (common != null) return common;
      return _json(_page([], hasMore: false));
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Sua lista está vazia'), findsOneWidget);
    expect(find.text('Adicione um item para começar.'), findsOneWidget);
    expect(find.text('Você chegou ao fim da lista.'), findsOneWidget);

    final errorClient = MockClient((request) async {
      final common = _commonResponse(request);
      if (common != null) return common;
      return _json({'message': 'Servidor indisponível'}, status: 503);
    });
    final errorState = await _state(errorClient);
    final selection = errorState.selectHouse(
      House(id: 7, name: 'Casa de teste'),
    );
    expect(errorState.houseLoading, isTrue);
    await selection;
    await tester.pumpWidget(_wrap(errorState));
    await tester.pumpAndSettle();

    expect(find.text('Servidor indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('toggle atualiza otimisticamente e reconcilia pela resposta', (
    tester,
  ) async {
    final patchResponse = Completer<http.Response>();
    final client = MockClient((request) async {
      final common = _commonResponse(request);
      if (common != null) return common;
      if (request.method == 'GET') {
        return _json(_page([_item(2)], hasMore: false));
      }
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/itens/2');
      expect(jsonDecode(request.body), {'comprado': true});
      expect(request.headers['x-casa-id'], '7');
      return patchResponse.future;
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();
    expect(find.text('Pendentes (1)'), findsOneWidget);
    expect(find.text('Comprados (0)'), findsOneWidget);

    final toggle = state.toggle(state.items.single);
    expect(state.items.single.bought, isTrue);
    expect(state.items.single.name, 'Item 2');
    expect(state.items.single.quantity, 3);
    expect(state.items.single.price, '12.50');
    expect(state.items.single.measure, 'un');
    expect(state.items, hasLength(1));

    patchResponse.complete(
      _json({
        'data': {
          ..._item(2),
          'nome': 'Nome canônico',
          'comprado': true,
          'updated_at': '2026-10-23T12:00:00.000000Z',
        },
      }),
    );
    await toggle;
    expect(state.items.single.bought, isTrue);
    expect(state.items.single.name, 'Nome canônico');
    expect(state.items, hasLength(1));
    await tester.pump();
    expect(find.text('Pendentes (0)'), findsOneWidget);
    expect(find.text('Comprados (1)'), findsOneWidget);
  });

  testWidgets('falha do PATCH restaura o item e mostra aviso', (tester) async {
    final patchResponse = Completer<http.Response>();
    final client = MockClient((request) async {
      final common = _commonResponse(request);
      if (common != null) return common;
      if (request.method == 'GET') {
        return _json(_page([_item(2)], hasMore: false));
      }
      return patchResponse.future;
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(state.items.single.bought, isTrue);
    patchResponse.complete(_json({'message': 'Indisponível'}, status: 503));
    await tester.pumpAndSettle();

    expect(state.items.single.bought, isFalse);
    expect(state.items.single.name, 'Item 2');
    expect(
      find.text('Não foi possível atualizar o item. Tente novamente.'),
      findsOneWidget,
    );
  });

  test('toques rápidos são serializados e convergem no estado final', () async {
    final firstPatch = Completer<http.Response>();
    var patchCalls = 0;
    final client = MockClient((request) async {
      final common = _commonResponse(request);
      if (common != null) return common;
      if (request.method == 'GET') {
        return _json(_page([_item(2)], hasMore: false));
      }
      patchCalls++;
      if (patchCalls == 1) return firstPatch.future;
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({
        'data': {
          ..._item(2),
          'comprado': payload['comprado'],
          'updated_at': '2026-10-23T12:00:00.000000Z',
        },
      });
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));

    final first = state.toggle(state.items.single);
    final second = state.toggle(state.items.single);
    expect(state.items.single.bought, isFalse);
    expect(patchCalls, 0);
    await Future<void>.delayed(Duration.zero);
    expect(patchCalls, 1);
    firstPatch.complete(
      _json({
        'data': {
          ..._item(2),
          'comprado': true,
          'updated_at': '2026-10-23T12:00:00.000000Z',
        },
      }),
    );
    await Future.wait([first, second]);
    expect(patchCalls, 2);
    expect(state.items.single.bought, isFalse);
    expect(state.items, hasLength(1));
  });

  test('requisições concorrentes não repetem a mesma página', () async {
    final pageTwo = Completer<http.Response>();
    var cursorRequests = 0;
    final client = MockClient((request) async {
      final common = _commonResponse(request);
      if (common != null) return common;
      if (request.url.queryParameters.isEmpty) {
        return _json(
          _page(
            List.generate(20, (index) => _item(index + 1)),
            hasMore: true,
            nextCursor: 'opaque-cursor-1',
          ),
        );
      }
      cursorRequests++;
      return pageTwo.future;
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa de teste'));

    final firstRequest = state.loadNextItems();
    final duplicateRequest = state.loadNextItems();
    await Future<void>.delayed(Duration.zero);
    expect(cursorRequests, 1);
    expect(state.itemsLoadingMore, isTrue);

    pageTwo.complete(_json(_page([_item(21)], hasMore: false)));
    await Future.wait([firstRequest, duplicateRequest]);
    expect(state.items, hasLength(21));
    expect(cursorRequests, 1);
  });
}
