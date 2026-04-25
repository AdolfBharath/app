class ShopItem {
  ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int price;
  final String imageUrl;
  final DateTime createdAt;

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.round() ?? 0,
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
