import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models/house.dart';
import 'models/item.dart';
import 'models/user.dart';

class AppState extends ChangeNotifier {
  final ApiClient api;
  User? user;
  List<House> houses = [];
  House? activeHouse;
  List<Item> items = [];
  bool loading = true;
  String? error;
  Timer? _timer;
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

  Future<void> register(String name, String email, String password) async {
    final r = await api.request(
      'POST',
      '/v1/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      },
    );
    await api.prefs.setString('auth_token', r['data']['token']);
    user = User.fromJson(r['data']['user']);
    await loadHouses();
    notifyListeners();
  }

  Future<void> clearSession() async {
    _timer?.cancel();
    await api.prefs.remove('auth_token');
    user = null;
    houses = [];
    activeHouse = null;
    items = [];
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
      activeHouse = null;
      items = [];
    }
    if (houses.length == 1) await selectHouse(houses.first);
  }

  Future<void> selectHouse(House house) async {
    activeHouse = house;
    items = [];
    error = null;
    notifyListeners();
    await refreshItems();
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshItems(silent: true),
    );
  }

  Future<void> refreshItems({bool silent = false}) async {
    if (activeHouse == null) return;
    try {
      final r = await api.request('GET', '/v1/itens', houseId: activeHouse!.id);
      items = (r['data'] as List).map((x) => Item.fromJson(x)).toList();
      error = null;
    } on ApiException catch (e) {
      if (e.status == 401) {
        await clearSession();
      } else if (e.status == 404) {
        houses.removeWhere((x) => x.id == activeHouse!.id);
        activeHouse = null;
        items = [];
      }
      error = e.message;
    }
    if (!silent) notifyListeners();
  }

  Future<void> join(String code) async {
    await api.request(
      'POST',
      '/v1/convites/entrar',
      body: {'codigo': code.trim().toUpperCase()},
    );
    await loadHouses();
  }

  Future<void> add(String name) async {
    if (activeHouse == null) return;
    await api.request(
      'POST',
      '/v1/itens',
      body: {'nome': name.trim()},
      houseId: activeHouse!.id,
    );
    await refreshItems();
  }

  Future<void> toggle(Item item) async {
    if (activeHouse == null) return;
    await api.request(
      'PATCH',
      '/v1/itens/${item.id}',
      body: {'marcado': !item.checked},
      houseId: activeHouse!.id,
    );
    await refreshItems();
  }

  Future<void> edit(Item item, String name) async {
    if (activeHouse == null) return;
    await api.request(
      'PATCH',
      '/v1/itens/${item.id}',
      body: {'nome': name.trim()},
      houseId: activeHouse!.id,
    );
    await refreshItems();
  }

  Future<void> remove(Item item) async {
    if (activeHouse == null) return;
    await api.request(
      'DELETE',
      '/v1/itens/${item.id}',
      houseId: activeHouse!.id,
    );
    await refreshItems();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
