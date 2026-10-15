class User {
  final int id;
  final String name, email;
  User({required this.id, required this.name, required this.email});
  factory User.fromJson(Map<String, dynamic> j) =>
      User(id: j['id'], name: j['name'], email: j['email']);
}

class House {
  final int id;
  final String name;
  House({required this.id, required this.name});
  factory House.fromJson(Map<String, dynamic> j) =>
      House(id: j['id'], name: j['nome']);
}

class Item {
  final int id;
  final String name;
  final bool checked;
  Item({required this.id, required this.name, required this.checked});
  factory Item.fromJson(Map<String, dynamic> j) =>
      Item(id: j['id'], name: j['nome'], checked: j['marcado'] == true);
}
