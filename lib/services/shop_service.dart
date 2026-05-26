import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shop_item.dart';
import 'api_base.dart';

class ShopService extends ApiServiceBase {
  ShopService._();
  static final ShopService instance = ShopService._();

  Future<List<ShopItem>> fetchShopItems() async {
    final rows = await getCachedJsonList(
      '/shop_items?select=id,name,price,image_url,created_at&order=created_at.desc&limit=$defaultPageSize',
      ttl: const Duration(minutes: 10),
      disk: true,
    );
    return rows.map<ShopItem>(ShopItem.fromJson).toList(growable: false);
  }

  Future<ShopItem> createShopItem({
    required String name,
    required int price,
    required String imageUrl,
  }) async {
    final uri = buildUri('/shop_items');
    final response = await http.post(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({
        'name': name,
        'price': price,
        'image_url': imageUrl,
      }),
    ).timeout(const Duration(seconds: 12));

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
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
    final uri = buildUri('/shop_items?id=eq.$itemId');
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (price != null) payload['price'] = price;
    if (imageUrl != null) payload['image_url'] = imageUrl;

    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 12));

    if (isSuccess(response)) {
      var decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty) decoded = decoded.first;
      if (decoded is Map<String, dynamic>) {
        return ShopItem.fromJson(decoded);
      }
      throw ApiException('Unexpected update item response format');
    }

    throwApiError(response, 'Failed to update shop item');
  }

  Future<void> deleteShopItem(String itemId) async {
    final uri = buildUri('/shop_items?id=eq.$itemId');
    final response = await http
        .delete(uri, headers: await buildAuthHeaders())
        .timeout(const Duration(seconds: 12));

    if (isSuccess(response)) return;
    throwApiError(response, 'Failed to delete shop item');
  }

  Future<int> purchaseItem({
    required String userId,
    required String itemId,
    required int itemPrice,
    required int currentCoins,
  }) async {
    final newBalance = currentCoins - itemPrice;
    if (newBalance < 0) {
      throw ApiException('Not enough coins to purchase this item');
    }

    // Update the user's coins directly in the users table
    final uri = buildUri('/users?id=eq.$userId');
    final response = await http.patch(
      uri,
      headers: await buildAuthHeaders(),
      body: jsonEncode({'coins': newBalance}),
    ).timeout(const Duration(seconds: 12));

    if (isSuccess(response)) {
      // Log the purchase to the notifications table (since events table is missing)
      try {
        await http.post(
          buildUri('/notifications'),
          headers: await buildAuthHeaders(),
          body: jsonEncode({
            'sender_id': userId,
            'title': 'Item Purchased',
            'message': itemId,
            'type': 'reward',
            'target_group': 'student',
          }),
        ).timeout(const Duration(seconds: 12));
        await http.post(
          buildUri('/notifications'),
          headers: await buildAuthHeaders(),
          body: jsonEncode({
            'sender_id': userId,
            'title': 'Reward purchased',
            'message': 'Your coin balance was updated for this purchase.',
            'type': 'shop',
            'target_group': 'student',
          }),
        ).timeout(const Duration(seconds: 12));
      } catch (e) {
        print('Failed to log purchase: $e');
      }

      return newBalance;
    }

    throwApiError(response, 'Failed to update user coins during purchase');
  }
}
