import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_mercado/api.dart';
import 'package:lista_mercado/screens/monthly_items_page.dart';
import 'package:lista_mercado/screens/monthly_lists_page.dart';
import 'package:lista_mercado/state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
Map<String, dynamic> _item({String name = 'Arroz'}) => {
  'id': name == 'Arroz' ? 1 : 2,
  'nome': name,
  'quantidade': 2,
  'medida': 'kg',
  'preco': '4.50',
  'comprado': false,
  'created_at': '2026-10-22T12:00:00.000000Z',
  'updated_at': '2026-10-22T12:00:00.000000Z',
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

Widget _wrap(AppState state, Widget child) => ChangeNotifierProvider.value(
  value: state,
  child: MaterialApp(home: child),
);

void main() {
  testWidgets(
    'carrega listas mensais com header da casa e lista fechada somente leitura',
    (tester) async {
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.path);
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(request.headers['x-casa-id'], '12');
        if (request.url.path == '/api/v1/casas/12/listas') {
          return _json({
            'data': [
              {
                'id': 88,
                'casa_id': 12,
                'ano': 2026,
                'mes': 10,
                'fechado_em': '2026-11-01T00:00:00Z',
              },
            ],
          });
        }
        if (request.url.path == '/api/v1/listas/88/itens') {
          return _json({
            'data': [_item()],
            'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
          });
        }
        return _json({
          'message': 'Not found',
          'type': 'not_found',
        }, status: 404);
      });
      final state = await _state(client);
      await tester.pumpWidget(
        _wrap(state, const MonthlyListsPage(houseId: 12)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Outubro de 2026'), findsOneWidget);
      expect(find.text('Lista fechada · somente leitura'), findsOneWidget);
      await tester.pumpWidget(
        _wrap(state, const MonthlyItemsPage(houseId: 12, listId: 88)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arroz'), findsOneWidget);
      expect(find.text('2 kg · R\$ 4,50'), findsOneWidget);
      expect(find.byTooltip('Editar item'), findsNothing);
      expect(requested, [
        '/api/v1/casas/12/listas',
        '/api/v1/casas/12/listas',
        '/api/v1/listas/88/itens',
      ]);
    },
  );

  testWidgets('404 de listas tem retry e lista vazia tem orientação', (
    tester,
  ) async {
    var attempts = 0;
    final client = MockClient((request) async {
      expect(request.headers['x-casa-id'], '42');
      attempts++;
      if (attempts == 1) {
        return _json({
          'message': 'Não encontrado',
          'type': 'not_found',
        }, status: 404);
      }
      return _json({'data': []});
    });
    final state = await _state(client);
    await tester.pumpWidget(_wrap(state, const MonthlyListsPage(houseId: 42)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Casa não encontrada ou sem acesso'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma lista mensal disponível'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('lista de outra casa retorna 404 acionável e não busca itens', (
    tester,
  ) async {
    var itemReads = 0;
    final client = MockClient((request) async {
      expect(request.headers['x-casa-id'], '42');
      if (request.url.path == '/api/v1/casas/42/listas') {
        return _json({'data': []});
      }
      if (request.url.path == '/api/v1/listas/88/itens') {
        itemReads++;
      }
      return _json({
        'message': 'Não encontrado',
        'type': 'not_found',
      }, status: 404);
    });
    final state = await _state(client);
    await tester.pumpWidget(
      _wrap(state, const MonthlyItemsPage(houseId: 42, listId: 88)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Lista não encontrada nesta casa'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(itemReads, 0);
  });

  testWidgets('lista aberta oferece edição e itens seguem cursor da API', (
    tester,
  ) async {
    final cursors = <String?>[];
    final client = MockClient((request) async {
      expect(request.headers['x-casa-id'], '12');
      if (request.url.path == '/api/v1/casas/12/listas') {
        return _json({
          'data': [
            {
              'id': 88,
              'casa_id': 12,
              'ano': 2026,
              'mes': 10,
              'fechado_em': null,
            },
          ],
        });
      }
      cursors.add(request.url.queryParameters['cursor']);
      if (request.url.queryParameters['cursor'] == null) {
        return _json({
          'data': [_item()],
          'meta': {'per_page': 1, 'has_more': true, 'next_cursor': 'cursor-1'},
        });
      }
      expect(request.url.queryParameters['cursor'], 'cursor-1');
      return _json({
        'data': [_item(name: 'Feijão')],
        'meta': {'per_page': 1, 'has_more': false, 'next_cursor': null},
      });
    });
    final state = await _state(client);
    await tester.pumpWidget(
      _wrap(state, const MonthlyItemsPage(houseId: 12, listId: 88)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('Abrir lista para editar'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Feijão'), findsOneWidget);
    expect(cursors, [null, 'cursor-1']);
  });

  testWidgets('copia do último mês anterior com itens para o destino vazio', (
    tester,
  ) async {
    var destinationReads = 0;
    String? copyPath;
    final client = MockClient((request) async {
      expect(request.headers['x-casa-id'], '12');
      if (request.url.path == '/api/v1/casas/12/listas') {
        return _json({
          'data': [
            {
              'id': 100,
              'casa_id': 12,
              'ano': 2026,
              'mes': 11,
              'fechado_em': null,
            },
            {
              'id': 99,
              'casa_id': 12,
              'ano': 2026,
              'mes': 10,
              'fechado_em': '2026-11-01',
            },
            {
              'id': 88,
              'casa_id': 12,
              'ano': 2026,
              'mes': 8,
              'fechado_em': '2026-09-01',
            },
            {
              'id': 77,
              'casa_id': 12,
              'ano': 2026,
              'mes': 7,
              'fechado_em': '2026-08-01',
            },
          ],
        });
      }
      if (request.url.path == '/api/v1/listas/99/itens') {
        return _json({
          'data': [],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      if (request.url.path == '/api/v1/listas/88/itens') {
        return _json({
          'data': [_item()],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      if (request.url.path == '/api/v1/listas/100/itens') {
        destinationReads++;
        return _json({
          'data': destinationReads == 1 ? [] : [_item()],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      if (request.method == 'POST') {
        copyPath = request.url.path;
        expect(request.body, '{}');
        return http.Response('', 204);
      }
      return _json({'message': 'Unexpected request'}, status: 500);
    });
    final state = await _state(client);
    await tester.pumpWidget(
      _wrap(state, const MonthlyItemsPage(houseId: 12, listId: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copiando de agosto/2026'), findsOneWidget);
    expect(find.text('Esta lista está vazia'), findsOneWidget);
    await tester.tap(find.text('Copiar itens para este mês'));
    await tester.pumpAndSettle();

    expect(copyPath, '/api/v1/listas/100/copiar-de/88');
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Itens copiados para a lista deste mês.'), findsOneWidget);
  });

  testWidgets(
    'sem mês anterior com itens, a cópia fica desabilitada com motivo',
    (tester) async {
      var copyRequests = 0;
      final client = MockClient((request) async {
        if (request.headers['x-casa-id'] != '12') {
          return _json({'message': 'House context missing'}, status: 400);
        }
        if (request.url.path == '/api/v1/casas/12/listas') {
          return _json({
            'data': [
              {'id': 100, 'ano': 2026, 'mes': 11, 'fechado_em': null},
              {'id': 99, 'ano': 2026, 'mes': 10, 'fechado_em': '2026-11-01'},
            ],
          });
        }
        if (request.url.path == '/api/v1/listas/99/itens' ||
            request.url.path == '/api/v1/listas/100/itens') {
          return _json({
            'data': [],
            'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
          });
        }
        if (request.method == 'POST') copyRequests++;
        return _json({'message': 'Unexpected request'}, status: 500);
      });
      final state = await _state(client);
      await tester.pumpWidget(
        _wrap(state, const MonthlyItemsPage(houseId: 12, listId: 100)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Não há uma lista anterior com itens para copiar.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Copiar itens para este mês'),
      );
      expect(button.onPressed, isNull);
      expect(copyRequests, 0);
    },
  );

  testWidgets('destino não vazio desabilita cópia e explica o motivo', (
    tester,
  ) async {
    var copyRequests = 0;
    final client = MockClient((request) async {
      expect(request.headers['x-casa-id'], '12');
      if (request.url.path == '/api/v1/casas/12/listas') {
        return _json({
          'data': [
            {'id': 100, 'ano': 2026, 'mes': 11, 'fechado_em': null},
            {'id': 88, 'ano': 2026, 'mes': 8, 'fechado_em': '2026-09-01'},
          ],
        });
      }
      if (request.url.path == '/api/v1/listas/88/itens') {
        return _json({
          'data': [_item()],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      if (request.url.path == '/api/v1/listas/100/itens') {
        return _json({
          'data': [_item(name: 'Feijão')],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      if (request.method == 'POST') copyRequests++;
      return _json({'message': 'Unexpected request'}, status: 500);
    });
    final state = await _state(client);
    await tester.pumpWidget(
      _wrap(state, const MonthlyItemsPage(houseId: 12, listId: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'A cópia só fica disponível quando a lista deste mês está vazia.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Copiar itens para este mês'),
    );
    expect(button.onPressed, isNull);
    expect(copyRequests, 0);
  });

  testWidgets('409 durante a cópia atualiza o destino e mostra conflito', (
    tester,
  ) async {
    var destinationReads = 0;
    final client = MockClient((request) async {
      expect(request.headers['x-casa-id'], '12');
      if (request.url.path == '/api/v1/casas/12/listas') {
        return _json({
          'data': [
            {'id': 100, 'ano': 2026, 'mes': 11, 'fechado_em': null},
            {'id': 88, 'ano': 2026, 'mes': 8, 'fechado_em': '2026-09-01'},
          ],
        });
      }
      if (request.url.path == '/api/v1/listas/88/itens') {
        return _json({
          'data': [_item()],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      if (request.url.path == '/api/v1/listas/100/itens') {
        destinationReads++;
        return _json({
          'data': destinationReads == 1 ? [] : [_item(name: 'Feijão')],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      if (request.method == 'POST') {
        return _json({
          'message': 'A lista de destino já possui itens.',
          'type': 'conflict',
          'error_code': 'lista_nao_vazia',
        }, status: 409);
      }
      return _json({'message': 'Unexpected request'}, status: 500);
    });
    final state = await _state(client);
    await tester.pumpWidget(
      _wrap(state, const MonthlyItemsPage(houseId: 12, listId: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar itens para este mês'));
    await tester.pumpAndSettle();

    expect(find.text('Feijão'), findsOneWidget);
    expect(
      find.textContaining('A lista do mês já recebeu itens'),
      findsOneWidget,
    );
  });

  testWidgets('falha ao verificar origem mostra retry acionável', (
    tester,
  ) async {
    var sourceReads = 0;
    final client = MockClient((request) async {
      expect(request.headers['x-casa-id'], '12');
      if (request.url.path == '/api/v1/casas/12/listas') {
        return _json({
          'data': [
            {'id': 100, 'ano': 2026, 'mes': 11, 'fechado_em': null},
            {'id': 88, 'ano': 2026, 'mes': 8, 'fechado_em': '2026-09-01'},
          ],
        });
      }
      if (request.url.path == '/api/v1/listas/88/itens') {
        sourceReads++;
        if (sourceReads == 1) {
          return _json({'message': 'Temporarily unavailable'}, status: 500);
        }
        return _json({
          'data': [_item()],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      if (request.url.path == '/api/v1/listas/100/itens') {
        return _json({
          'data': [],
          'meta': {'per_page': 20, 'has_more': false, 'next_cursor': null},
        });
      }
      return _json({'message': 'Unexpected request'}, status: 500);
    });
    final state = await _state(client);
    await tester.pumpWidget(
      _wrap(state, const MonthlyItemsPage(houseId: 12, listId: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível verificar a lista de origem. Tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tentar verificar novamente'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Copiar itens para este mês'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Tentar verificar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Copiando de agosto/2026'), findsOneWidget);
    expect(sourceReads, 2);
  });
}
