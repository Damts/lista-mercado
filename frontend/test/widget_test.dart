import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sessão local é removível sem manter token', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'token-de-teste'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'token-de-teste');
    await prefs.remove('auth_token');
    expect(prefs.getString('auth_token'), isNull);
  });

  test('erro 401 é um erro de API tratável', () {
    final error = ApiException(401, 'Sessão expirada. Entre novamente.');
    expect(error.status, 401);
    expect(error.message, contains('Sessão expirada'));
  });
}
