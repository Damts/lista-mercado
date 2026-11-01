import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models/house.dart';
import 'models/item.dart';
import 'models/item_page.dart';
import 'models/monthly_list.dart';
import 'models/user.dart';

class AppState extends ChangeNotifier {
  final ApiClient api;
  User? user;
  List<House> houses = [];
  House? activeHouse;
  List<MonthlyList> monthlyLists = [];
  MonthlyList? activeList;
  bool listsLoading = false;
  String? listsError;
  List<Item> items = [];
  bool loading = true;
  String? error;
  bool houseLoading = false;
  String? houseError;
  House? _requestedHouse;
  bool itemsLoading = false;
  bool itemsLoadingMore = false;
  bool hasMoreItems = false;
  String? nextItemsCursor;
  String? itemsError;
  int _itemsGeneration = 0;
  final Set<String> _usedCursors = {};

  AppState(this.api);

  bool get authenticated => api.token != null && user != null;
  bool get canEditItems => activeList?.isClosed != true;

  void markActiveListClosed() {
    final current = activeList;
    if (current == null || current.isClosed) return;
    final closed = MonthlyList(
      id: current.id,
      houseId: current.houseId,
      year: current.year,
      month: current.month,
      closedAt: DateTime.now(),
    );
    monthlyLists = monthlyLists
        .map((list) => list.id == closed.id ? closed : list)
        .toList(growable: false);
    activeList = closed;
    notifyListeners();
  }

  Future<dynamic> _writeRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required int houseId,
  }) async {
    try {
      return await api.request(method, path, body: body, houseId: houseId);
    } on ApiException catch (exception) {
      if (exception.errorCode == 'lista_fechada') markActiveListClosed();
      rethrow;
    }
  }

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
    monthlyLists = [];
    activeList = null;
    listsLoading = false;
    listsError = null;
    _requestedHouse = null;
    houseLoading = false;
    houseError = null;
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
      monthlyLists = [];
      activeList = null;
      _requestedHouse = null;
      houseLoading = false;
      houseError = null;
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
    _requestedHouse = house;
    await _loadHouse(house);
  }

  Future<void> retryHouse() async {
    final house = _requestedHouse;
    if (house == null) return;
    await _loadHouse(house);
  }

  Future<void> _loadHouse(House house) async {
    final generation = ++_itemsGeneration;
    activeHouse = null;
    monthlyLists = [];
    activeList = null;
    listsLoading = true;
    listsError = null;
    items = [];
    houseLoading = true;
    houseError = null;
    itemsLoading = false;
    itemsLoadingMore = false;
    hasMoreItems = false;
    nextItemsCursor = null;
    itemsError = null;
    _usedCursors.clear();
    notifyListeners();

    try {
      final response = await api.request('GET', '/v1/casas/${house.id}');
      if (generation != _itemsGeneration) return;
      final loadedHouse = House.fromJson(response['data']);
      activeHouse = loadedHouse;
      if (!houses.any((current) => current.id == loadedHouse.id)) {
        houses = [...houses, loadedHouse];
      }
      houseLoading = false;
      await loadMonthlyLists(generation);
    } catch (exception) {
      if (generation != _itemsGeneration) return;
      if (exception is ApiException && exception.status == 401) {
        await clearSession();
        return;
      }
      if (exception is ApiException && exception.status == 404) {
        houses.removeWhere((current) => current.id == house.id);
      }
      houseLoading = false;
      itemsLoading = false;
      houseError = _houseErrorMessage(exception);
      notifyListeners();
    }
  }

  Future<void> loadMonthlyLists([int? expectedGeneration]) async {
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    final generation = expectedGeneration ?? ++_itemsGeneration;
    listsLoading = true;
    listsError = null;
    notifyListeners();
    try {
      final response = await api.request(
        'GET',
        '/v1/casas/$houseId/listas',
        houseId: houseId,
      );
      if (generation != _itemsGeneration || activeHouse?.id != houseId) return;
      final rawLists = response['data'];
      if (rawLists is! List) {
        throw const FormatException('Resposta de listas mensais inválida.');
      }
      final loadedLists = rawLists
          .map((entry) => MonthlyList.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false);
      if (loadedLists.any((list) => list.houseId != houseId)) {
        throw const FormatException('A lista não pertence à casa selecionada.');
      }
      monthlyLists = loadedLists;
      activeList = monthlyLists.isEmpty ? null : monthlyLists.first;
      listsLoading = false;
      if (activeList != null) {
        await _loadItemsPage(
          generation,
          activeList!.id,
          cursor: null,
          firstPage: true,
        );
      } else {
        items = [];
        itemsLoading = false;
        notifyListeners();
      }
    } catch (exception) {
      if (generation != _itemsGeneration || activeHouse?.id != houseId) return;
      if (exception is ApiException && exception.status == 401) {
        await clearSession();
        return;
      }
      listsLoading = false;
      listsError = _messageFor(exception);
      items = [];
      itemsLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectMonthlyList(MonthlyList list) async {
    if (!monthlyLists.any((candidate) => candidate.id == list.id)) return;
    final generation = ++_itemsGeneration;
    activeList = list;
    items = [];
    hasMoreItems = false;
    nextItemsCursor = null;
    itemsError = null;
    _usedCursors.clear();
    notifyListeners();
    await _loadItemsPage(generation, list.id, cursor: null, firstPage: true);
  }

  Future<void> refreshItems({bool silent = false}) async {
    final listId = activeList?.id;
    if (listId == null) return;
    final generation = ++_itemsGeneration;
    hasMoreItems = false;
    nextItemsCursor = null;
    itemsLoading = true;
    itemsLoadingMore = false;
    itemsError = null;
    _usedCursors.clear();
    if (!silent) notifyListeners();
    await _loadItemsPage(generation, listId, cursor: null, firstPage: true);
  }

  Future<void> loadNextItems() async {
    final listId = activeList?.id;
    final cursor = nextItemsCursor;
    if (listId == null ||
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
      listId,
      cursor: cursor,
      firstPage: false,
    );
  }

  Future<void> _loadItemsPage(
    int generation,
    int listId, {
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
      final query = cursor == null
          ? ''
          : '?cursor=${Uri.encodeQueryComponent(cursor)}';
      final response = await api.request(
        'GET',
        '/v1/listas/$listId/itens$query',
        houseId: activeHouse?.id,
      );
      final page = ItemPage.fromJson(response as Map<String, dynamic>);
      if (generation != _itemsGeneration || activeList?.id != listId) return;
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
      if (generation != _itemsGeneration || activeList?.id != listId) return;
      if (exception is ApiException && exception.status == 401) {
        await clearSession();
        return;
      }
      if (exception is ApiException && exception.status == 404) {
        monthlyLists = monthlyLists.where((list) => list.id != listId).toList();
        activeList = null;
        items = [];
        hasMoreItems = false;
        nextItemsCursor = null;
        houseError = _houseErrorMessage(exception);
      }
      itemsError = _messageFor(exception);
    } finally {
      if (generation == _itemsGeneration && activeList?.id == listId) {
        itemsLoading = false;
        itemsLoadingMore = false;
        notifyListeners();
      }
    }
  }

  String _houseErrorMessage(Object exception) {
    if (exception is ApiException && exception.status == 404) {
      return 'Casa não encontrada ou sem acesso. Tente novamente ou volte para suas casas.';
    }
    return exception is ApiException
        ? exception.message
        : 'Não foi possível carregar a casa. Verifique a conexão e tente novamente.';
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

  void _ensureListEditable() {
    if (!canEditItems) {
      throw ApiException(
        409,
        'Esta lista está fechada e não pode ser alterada.',
        'conflict',
        'lista_fechada',
      );
    }
  }

  Future<void> add(String name, {required int quantity, String? price}) async {
    _ensureListEditable();
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    await _writeRequest(
      'POST',
      '/v1/itens',
      body: {'nome': name.trim(), 'quantidade': quantity, 'preco': price},
      houseId: houseId,
    );
    await refreshItems();
  }

  Future<void> toggle(Item item) async {
    _ensureListEditable();
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    final response = await _writeRequest(
      'PATCH',
      '/v1/itens/${item.id}',
      body: {'comprado': !item.bought},
      houseId: houseId,
    );
    _replaceUpdatedItem(Item.fromJson(response['data']));
  }

  Future<Item> updateItem({
    required Item item,
    required String name,
    required int quantity,
    required String measure,
    required String? price,
    required bool bought,
  }) async {
    _ensureListEditable();
    final houseId = activeHouse?.id;
    if (houseId == null) throw StateError('Nenhuma casa selecionada.');
    final response = await _writeRequest(
      'PATCH',
      '/v1/itens/${item.id}',
      body: {
        'nome': name.trim(),
        'quantidade': quantity,
        'medida': measure,
        'preco': price,
        'comprado': bought,
      },
      houseId: houseId,
    );
    final updated = Item.fromJson(response['data']);
    _replaceUpdatedItem(updated);
    return updated;
  }

  void _replaceUpdatedItem(Item updated) {
    final uniqueItems = <int, Item>{updated.id: updated};
    for (final current in items) {
      uniqueItems.putIfAbsent(current.id, () => current);
    }
    final otherItems =
        uniqueItems.values.where((current) => current.id != updated.id).toList()
          ..sort((left, right) {
            final timestampOrder = right.updatedAt.compareTo(left.updatedAt);
            return timestampOrder != 0
                ? timestampOrder
                : right.id.compareTo(left.id);
          });
    items = [updated, ...otherItems];
    notifyListeners();
  }

  Future<void> remove(Item item) async {
    _ensureListEditable();
    final houseId = activeHouse?.id;
    if (houseId == null) return;
    await _writeRequest('DELETE', '/v1/itens/${item.id}', houseId: houseId);
    items = items
        .where((current) => current.id != item.id)
        .toList(growable: false);
    notifyListeners();
  }
}
