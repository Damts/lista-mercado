class Item {
  final int id;
  final String name;
  final int quantity;
  final String? price;
  final bool bought;

  const Item({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.bought,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    id: (json['id'] as num).toInt(),
    name: json['nome'] as String,
    quantity: (json['quantidade'] as num).toInt(),
    price: json['preco']?.toString(),
    bought: json['comprado'] as bool? ?? false,
  );

  Item copyWith({String? name, int? quantity, String? price, bool? bought}) =>
      Item(
        id: id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        price: price ?? this.price,
        bought: bought ?? this.bought,
      );
}
