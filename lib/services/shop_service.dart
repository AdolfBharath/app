import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shop_item.dart';
import 'api_base.dart';

class ShopService extends ApiServiceBase {
  ShopService._();
  static final ShopService instance = ShopService._();

  Future<List<ShopItem>> fetchShopItems() async {
    final uri = buildUri('/shop/items');
    final response = await http.get(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Unexpected shop items response format');
    }

    throwApiError(response, 'Failed to load shop items');
  }

  Future<ShopItem> createShopItem({
    required String name,
    required int price,
    required String imageUrl,
  }) async {
    final uri = buildUri('/admin/shop/items');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'name': name,
        'price': price,
        'image_url': imageUrl,
      }),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return ShopItem.fromJson(decoded);
      }
      throw ApiException('Unexpected create item response format');
    }

    throwApiError(response, 'Failed to create shop item');
  }

  Future<ShopItem> updateShopItem({
    required String itemId,
    String? name,
    int? price,
    String? imageUrl,
  }) async {
    final uri = buildUri('/admin/shop/items/$itemId');
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (price != null) payload['price'] = price;
    if (imageUrl != null) payload['image_url'] = imageUrl;

    final response = await http.put(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(payload),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return ShopItem.fromJson(decoded);
      }
      throw ApiException('Unexpected update item response format');
    }

    throwApiError(response, 'Failed to update shop item');
  }

  Future<void> deleteShopItem(String itemId) async {
    final uri = buildUri('/admin/shop/items/$itemId');
    final response = await http.delete(uri, headers: await buildAuthHeaders());

    if (isSuccess(response)) return;
    throwApiError(response, 'Failed to delete shop item');
  }

  Future<int> purchaseItem(String itemId) async {
    final uri = buildUri('/shop/purchase');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({'item_id': itemId}),
    );

    if (isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['remaining_coins'] as num?)?.toInt() ?? 0;
      }
      throw ApiException('Unexpected purchase response format');
    }

    throwApiError(response, 'Failed to purchase item');
  }
}
