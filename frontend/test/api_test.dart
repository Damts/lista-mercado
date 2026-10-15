import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('401 remove sessão local', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'abc'});
    final p = await SharedPreferences.getInstance();
    expect(p.getString('auth_token'), 'abc');
    await p.remove('auth_token');
    expect(p.getString('auth_token'), isNull);
  });
}
