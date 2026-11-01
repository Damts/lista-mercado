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

Map<String, dynamic> _item(int id, String name) => {
  'id': id,
  'nome': name,
  'quantidade': 1,
  'medida': 'un',
  'preco': '2.50',
  'comprado': false,
  'created_at': '2026-10-01T12:00:00.000000Z',
  'updated_at': '2026-10-01T12:00:00.000000Z',
};

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
  'data': items,
  'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
};

Map<String, dynamic> _list(int id, int month, {String? closedAt}) => {
  'id': id,
  'casa_id': 7,
  'ano': 2026,
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
  testWidgets('copia da última lista anterior com itens e atualiza o destino', (
    tester,
  ) async {
    final requests = <String>[];
    var destinationReads = 0;
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa'},
        });
      }
      if (request.url.path == '/api/v1/casas/7/listas') {
        return _json({
          'data': [_list(100, 11), _list(90, 10), _list(80, 8)],
        });
      }
      if (request.url.path == '/api/v1/listas/100/itens') {
        destinationReads++;
        return _json(
          _page(destinationReads == 1 ? [] : [_item(101, 'Feijão')]),
        );
      }
      if (request.url.path == '/api/v1/listas/90/itens') {
        return _json(_page([]));
      }
      if (request.url.path == '/api/v1/listas/80/itens') {
        return _json(_page([_item(81, 'Feijão anterior')]));
      }
      if (request.url.path == '/api/v1/listas/100/copiar-de/80') {
        expect(request.method, 'POST');
        expect(request.headers['x-casa-id'], '7');
        return http.Response('', 204);
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Copiando de agosto/2026'), findsOneWidget);
    final buttonFinder = find.widgetWithText(
      FilledButton,
      'Copiar itens para este mês',
    );
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(requests, contains('POST /api/v1/listas/100/copiar-de/80'));
    expect(destinationReads, 2);
    expect(find.text('Feijão'), findsOneWidget);
    expect(find.text('Itens copiados para este mês.'), findsOneWidget);
  });

  testWidgets('sem origem com itens, explica e desabilita a cópia', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa'},
        });
      }
      if (request.url.path == '/api/v1/casas/7/listas') {
        return _json({
          'data': [_list(100, 11)],
        });
      }
      if (request.url.path == '/api/v1/listas/100/itens') {
        return _json(_page([]));
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(
      find.text('Não há uma lista anterior com itens para copiar.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Copiar itens para este mês'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('destino preenchido explica e desabilita a cópia', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa'},
        });
      }
      if (request.url.path == '/api/v1/casas/7/listas') {
        return _json({
          'data': [_list(100, 11), _list(90, 10)],
        });
      }
      if (request.url.path == '/api/v1/listas/100/itens') {
        return _json(_page([_item(101, 'Item existente')]));
      }
      if (request.url.path == '/api/v1/listas/90/itens') {
        return _json(_page([_item(91, 'Item anterior')]));
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'A cópia só fica disponível enquanto a lista deste mês estiver vazia.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Copiar itens para este mês'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('409 lista_nao_vazia atualiza o destino e impede novo envio', (
    tester,
  ) async {
    var destinationReads = 0;
    var copyRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/casas/7') {
        return _json({
          'data': {'id': 7, 'nome': 'Casa'},
        });
      }
      if (request.url.path == '/api/v1/casas/7/listas') {
        return _json({
          'data': [_list(100, 11), _list(90, 10)],
        });
      }
      if (request.url.path == '/api/v1/listas/100/itens') {
        destinationReads++;
        return _json(
          _page(destinationReads == 1 ? [] : [_item(101, 'Item concorrente')]),
        );
      }
      if (request.url.path == '/api/v1/listas/90/itens') {
        return _json(_page([_item(91, 'Item anterior')]));
      }
      if (request.url.path == '/api/v1/listas/100/copiar-de/90') {
        copyRequests++;
        return _json({
          'message': 'Destino preenchido.',
          'type': 'conflict',
          'error_code': 'lista_nao_vazia',
        }, status: 409);
      }
      return _json({'message': 'Não encontrado'}, status: 404);
    });
    final state = await _state(client);
    await state.selectHouse(House(id: 7, name: 'Casa'));
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Copiar itens para este mês'),
    );
    await tester.pumpAndSettle();

    expect(copyRequests, 1);
    expect(find.text('Item concorrente'), findsOneWidget);
    expect(find.textContaining('já tem itens'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Copiar itens para este mês'),
    );
    expect(button.onPressed, isNull);
  });
}
