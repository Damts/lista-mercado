import 'item.dart';

class ItemPage {
  final List<Item> items;
  final bool hasMore;
  final String? nextCursor;

  const ItemPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  factory ItemPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['data'];
    final meta = json['meta'];
    if (rawItems is! List || meta is! Map<String, dynamic>) {
      throw const FormatException('Resposta paginada de itens inválida.');
    }

    final hasMore = meta['has_more'];
    final nextCursor = meta['next_cursor'];
    if (hasMore is! bool || (nextCursor != null && nextCursor is! String)) {
      throw const FormatException('Metadados de paginação inválidos.');
    }

    return ItemPage(
      items: rawItems
          .map((item) => Item.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: nextCursor as String?,
    );
  }
}
