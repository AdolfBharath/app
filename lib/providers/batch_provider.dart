import 'package:flutter/foundation.dart';

import '../models/batch.dart';
import '../services/api_service.dart' as admin_api;

class BatchProvider extends ChangeNotifier {
  final List<Batch> _batches = [];
  String? _errorMessage;
  bool _isLoading = false;

  List<Batch> get batches => List.unmodifiable(_batches);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> loadBatches() async {
    // Don't notify during build - just set the flag
    _isLoading = true;
    _errorMessage = null;

    try {
      final list = await admin_api.ApiService.instance.getBatches();
      _batches
        ..clear()
        ..addAll(list);
      _errorMessage = null;
    } on admin_api.UnauthorizedApiException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        print('Load batches failed (Unauthorized): ${e.message}');
      }
    } on admin_api.ApiException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        print('Load batches failed: ${e.message}');
      }
    } catch (e) {
      _errorMessage = 'Failed to load batches: $e';
      if (kDebugMode) {
        print('Load batches unexpected error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addBatch({
    required String name,
    required String courseId,
    String? mentorId,
    int? capacity,
    int? enrollLimit,
    bool smartWaitlist = false,
    DateTime? startDate,
  }) async {
    try {
      await admin_api.ApiService.instance.createBatch(
        name: name,
        courseId: courseId,
        mentorId: mentorId,
        capacity: capacity,
        enrollLimit: enrollLimit,
        smartWaitlist: smartWaitlist,
        startDate: startDate,
      );

      await loadBatches();
      return true;
    } on admin_api.ApiException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        print('Add batch failed: ${e.message}');
      }
      return false;
    }
  }

  Future<bool> deleteBatch(Batch batch) async {
    try {
      await admin_api.ApiService.instance.deleteBatch(batch.id);
      await loadBatches();
      return true;
    } on admin_api.ApiException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        print('Delete batch failed: ${e.message}');
      }
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
