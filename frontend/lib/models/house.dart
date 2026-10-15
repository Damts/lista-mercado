class House {
  final int id;
  final String name;

  House({required this.id, required this.name});

  factory House.fromJson(Map<String, dynamic> json) =>
      House(id: json['id'], name: json['nome']);
}
