class Item {
  final int id;
  final String name;
  final bool checked;

  Item({required this.id, required this.name, required this.checked});

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    id: json['id'],
    name: json['nome'],
    checked: json['marcado'] == true,
  );
}
