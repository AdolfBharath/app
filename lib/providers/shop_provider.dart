import 'package:flutter/foundation.dart';

import '../models/shop_item.dart';
import '../services/api_base.dart';
import '../services/shop_service.dart';

class ShopProvider extends ChangeNotifier {
  final List<ShopItem> _items = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<ShopItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> fetchShopItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await ShopService.instance.fetchShopItems();
      _items
        ..clear()
        ..addAll(list);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        print('Fetch shop items failed: ${e.message}');
      }
    } catch (e) {
      _errorMessage = 'Failed to load shop items: $e';
      if (kDebugMode) {
        print('Fetch shop items unexpected error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createShopItem({
    required String name,
    required int price,
    required String imageUrl,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final item = await ShopService.instance.createShopItem(
        name: name,
        price: price,
        imageUrl: imageUrl,
      );
      _items.insert(0, item);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to create shop item: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateShopItem({
    required String itemId,
    required String name,
    required int price,
    required String imageUrl,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await ShopService.instance.updateShopItem(
        itemId: itemId,
        name: name,
        price: price,
        imageUrl: imageUrl,
      );
      final i = _items.indexWhere((item) => item.id == itemId);
      if (i >= 0) {
        _items[i] = updated;
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update shop item: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteShopItem(String itemId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ShopService.instance.deleteShopItem(itemId);
      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete shop item: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<int?> purchaseItem(String itemId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final remainingCoins = await ShopService.instance.purchaseItem(itemId);
      return remainingCoins;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Purchase failed: $e';
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
