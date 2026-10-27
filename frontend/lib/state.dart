import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models/house.dart';
import 'models/item.dart';
import 'models/item_page.dart';
import 'models/user.dart';

class AppState extends ChangeNotifier {
  final ApiClient api;
  User? user;
  List<House> houses = [];
  House? activeHouse;
  List<Item> items = [];
  bool loading = true;
  String? error;
  bool itemsLoading = false;
  bool itemsLoadingMore = false;
  bool hasMoreItems = false;
  String? nextItemsCursor;
  String? itemsError;
  int _itemsGeneration = 0;
  final Set<String> _usedCursors = {};

  AppState(this.api);

  bool get authenticated => api.token != null && user != null;

  Future<void> bootstrap() async {
    if (api.token == null) {
      loading = false;
      notifyListeners();
      return;
    }
    try {
      final r = await api.request('GET', '/v1/auth/me');
      user = User.fromJson(r['data']['user']);
      await loadHouses();
    } on ApiException catch (e) {
      if (e.status == 401) await clearSession();
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final r = await api.request(
      'POST',
      '/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    await api.prefs.setString('auth_token', r['data']['token']);
    user = User.fromJson(r['data']['user']);
    await loadHouses();
    notifyListeners();
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    final r = await api.request(
      'POST',
      '/v1/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    await api.prefs.setString('auth_token', r['data']['token']);
    user = User.fromJson(r['data']['user']);
    await loadHouses();
    notifyListeners();
  }

  Future<void> clearSession() async {
    _itemsGeneration++;
    await api.prefs.remove('auth_token');
    user = null;
    houses = [];
    activeHouse = null;
    items = [];
    itemsLoading = false;
    itemsLoadingMore = false;
    hasMoreItems = false;
    nextItemsCursor = null;
    itemsError = null;
    _usedCursors.clear();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.request('POST', '/v1/auth/logout');
    } finally {
      await clearSession();
    }
  }

  Future<void> loadHouses() async {
    final r = await api.request('GET', '/v1/casas');
    houses = (r['data'] as List).map((x) => House.fromJson(x)).toList();
    if (activeHouse != null && !houses.any((x) => x.id == activeHouse!.id)) {
      _itemsGeneration++;
      activeHouse = null;
      items = [];
      itemsLoading = false;
      itemsLoadingMore = false;
      hasMoreItems = false;
      nextItemsCursor = null;
      itemsError = null;
    }
    if (houses.length == 1) await selectHouse(houses.first);
    notifyListeners();
  }

  Future<void> selectHouse(House house) async {
    final generation = ++_itemsGeneration;
    activeHouse = house;
    items = [];
    itemsLoading = true;
    itemsLoadingMore = false;
    hasMoreItems = false;
    nextItemsCursor = null;
    itemsError = null;
    _usedCursors.clear();
    notifyListeners();

    try {
      final response = await api.request(
        'GET',
        '/v1/casa-atual',
        houseId: house.id,
      );
      if (generation != _itemsGeneration) return;
      activeHouse = House.fromJson(response['data']);
      await _loadItemsPage(generation, house.id, cursor: null, firstPage: true);
    } catch (exception) {
      if (generation != _itemsGeneration) return;
      await _handleHouseError(exception, house.id);
      if (generation == _itemsGeneration) {
        itemsLoading = false;
        itemsError = _messageFor(exception);
        notifyListeners();
      }
    }
  }

  Future<void> refreshItems({bool silent = false}) async {
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    final generation = ++_itemsGeneration;
    hasMoreItems = false;
    nextItemsCursor = null;
    itemsLoading = true;
    itemsLoadingMore = false;
    itemsError = null;
    _usedCursors.clear();
    if (!silent) notifyListeners();
    await _loadItemsPage(generation, houseId, cursor: null, firstPage: true);
  }

  Future<void> loadNextItems() async {
    final houseId = activeHouse?.id;
    final cursor = nextItemsCursor;
    if (houseId == null ||
        cursor == null ||
        !hasMoreItems ||
        itemsLoading ||
        itemsLoadingMore) {
      return;
    }
    if (_usedCursors.contains(cursor)) {
      itemsError =
          'A paginação retornou um cursor repetido. Tente atualizar a lista.';
      notifyListeners();
      return;
    }
    await _loadItemsPage(
      _itemsGeneration,
      houseId,
      cursor: cursor,
      firstPage: false,
    );
  }

  Future<void> _loadItemsPage(
    int generation,
    int houseId, {
    required String? cursor,
    required bool firstPage,
  }) async {
    if (firstPage) {
      itemsLoading = true;
    } else {
      itemsLoadingMore = true;
    }
    itemsError = null;
    notifyListeners();

    try {
      final path = cursor == null
          ? '/v1/itens'
          : '/v1/itens?cursor=${Uri.encodeQueryComponent(cursor)}';
      final response = await api.request('GET', path, houseId: houseId);
      final page = ItemPage.fromJson(response as Map<String, dynamic>);
      if (generation != _itemsGeneration || activeHouse?.id != houseId) return;
      if (page.hasMore &&
          (page.nextCursor == null || page.nextCursor!.isEmpty)) {
        throw const FormatException('A próxima página não informou um cursor.');
      }
      if (cursor != null &&
          (page.nextCursor == cursor ||
              (page.nextCursor != null &&
                  _usedCursors.contains(page.nextCursor)))) {
        throw const FormatException('A paginação retornou um cursor repetido.');
      }

      final existingIds = firstPage
          ? <int>{}
          : items.map((item) => item.id).toSet();
      final pageItems = page.items
          .where((item) => existingIds.add(item.id))
          .toList(growable: false);
      items = firstPage ? pageItems : [...items, ...pageItems];
      if (cursor != null) _usedCursors.add(cursor);
      nextItemsCursor = page.nextCursor;
      hasMoreItems = page.hasMore;
      itemsError = null;
    } catch (exception) {
      if (generation != _itemsGeneration || activeHouse?.id != houseId) return;
      if (exception is ApiException && exception.status == 401) {
        await clearSession();
        return;
      }
      if (exception is ApiException && exception.status == 404) {
        houses.removeWhere((house) => house.id == houseId);
        activeHouse = null;
        items = [];
        hasMoreItems = false;
        nextItemsCursor = null;
      }
      itemsError = _messageFor(exception);
    } finally {
      if (generation == _itemsGeneration) {
        itemsLoading = false;
        itemsLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _handleHouseError(Object exception, int houseId) async {
    if (exception is ApiException && exception.status == 401) {
      await clearSession();
    } else if (exception is ApiException && exception.status == 404) {
      houses.removeWhere((house) => house.id == houseId);
      activeHouse = null;
      items = [];
    }
  }

  String _messageFor(Object exception) => exception is ApiException
      ? exception.message
      : 'Não foi possível carregar os itens. Verifique a conexão e tente novamente.';

  Future<void> join(String code) async {
    await api.request(
      'POST',
      '/v1/convites/entrar',
      body: {'codigo': code.trim().toUpperCase()},
    );
    await loadHouses();
  }

  Future<String> createInvite(int houseId) async {
    final r = await api.request('POST', '/v1/casas/$houseId/convites');
    return r['data']['codigo'] as String;
  }

  Future<House> createHouse(String name) async {
    final r = await api.request(
      'POST',
      '/v1/casas',
      body: {'nome': name.trim()},
    );
    final house = House.fromJson(r['data']);
    await loadHouses();
    notifyListeners();
    return house;
  }

  Future<void> add(String name, {required int quantity, double? price}) async {
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    await api.request(
      'POST',
      '/v1/itens',
      body: {'nome': name.trim(), 'quantidade': quantity, 'preco': price},
      houseId: houseId,
    );
    await refreshItems();
  }

  Future<void> toggle(Item item) async {
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    await api.request(
      'PATCH',
      '/v1/itens/${item.id}',
      body: {'comprado': !item.bought},
      houseId: houseId,
    );
    items = items
        .map(
          (current) => current.id == item.id
              ? current.copyWith(bought: !item.bought)
              : current,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> edit(Item item, String name) async {
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    await api.request(
      'PATCH',
      '/v1/itens/${item.id}',
      body: {'nome': name.trim()},
      houseId: houseId,
    );
    items = items
        .map(
          (current) => current.id == item.id
              ? current.copyWith(name: name.trim())
              : current,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> remove(Item item) async {
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    await api.request('DELETE', '/v1/itens/${item.id}', houseId: houseId);
    items = items
        .where((current) => current.id != item.id)
        .toList(growable: false);
    notifyListeners();
  }
}
