class MonthlyList {
  final int id;
  final int houseId;
  final int year;
  final int month;
  final DateTime? closedAt;

  const MonthlyList({
    required this.id,
    required this.houseId,
    required this.year,
    required this.month,
    required this.closedAt,
  });

  bool get isClosed => closedAt != null;

  String get label {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    if (month < 1 || month > 12) {
      throw const FormatException('Mês da lista inválido.');
    }
    final name = months[month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} de $year';
  }

  factory MonthlyList.fromJson(Map<String, dynamic> json) {
    final rawClosedAt = json['fechado_em'];
    return MonthlyList(
      id: (json['id'] as num).toInt(),
      houseId: (json['casa_id'] as num).toInt(),
      year: (json['ano'] as num).toInt(),
      month: (json['mes'] as num).toInt(),
      closedAt: rawClosedAt == null
          ? null
          : DateTime.parse(rawClosedAt as String),
    );
  }
}
