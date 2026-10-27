class Item {
  final int id;
  final String name;
  final int quantity;
  final String measure;
  final String? price;
  final bool bought;
  final DateTime updatedAt;

  const Item({
    required this.id,
    required this.name,
    required this.quantity,
    required this.measure,
    required this.price,
    required this.bought,
    required this.updatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    id: (json['id'] as num).toInt(),
    name: json['nome'] as String,
    quantity: (json['quantidade'] as num).toInt(),
    measure: json['medida'] as String,
    price: json['preco']?.toString(),
    bought: json['comprado'] as bool? ?? false,
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}
