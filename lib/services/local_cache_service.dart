import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  static const _boxName = 'api_cache_v1';
  final Map<String, _MemoryEntry> _memory = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  Box<String>? _box;

  bool get isReady => _box?.isOpen == true;

  Future<void> init() async {
    if (isReady) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(_boxName);
    } catch (e) {
      if (kDebugMode) {
        print('Hive cache init failed: $e');
      }
    }
  }

  Future<T> remember<T>(
    String key,
    Future<T> Function() loader, {
    Duration ttl = const Duration(minutes: 5),
    bool disk = false,
    T Function(dynamic decoded)? fromJson,
  }) async {
    final now = DateTime.now();
    final memoryEntry = _memory[key];
    if (memoryEntry != null && now.isBefore(memoryEntry.expiresAt)) {
      return memoryEntry.value as T;
    }

    if (disk && isReady && fromJson != null) {
      final cached = _box!.get(key);
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached) as Map<String, dynamic>;
          final expiresAt = DateTime.tryParse(
            decoded['expiresAt']?.toString() ?? '',
          );
          if (expiresAt != null && now.isBefore(expiresAt)) {
            final value = fromJson(decoded['value']);
            _memory[key] = _MemoryEntry(value, expiresAt);
            return value;
          }
        } catch (_) {
          await _box!.delete(key);
        }
      }
    }

    final existing = _inFlight[key];
    if (existing != null) return existing as Future<T>;

    final future = loader().then((value) async {
      final expiresAt = DateTime.now().add(ttl);
      _memory[key] = _MemoryEntry(value, expiresAt);
      if (disk && isReady) {
        try {
          await _box!.put(
            key,
            jsonEncode({
              'expiresAt': expiresAt.toIso8601String(),
              'value': value,
            }),
          );
        } catch (_) {}
      }
      return value;
    }).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  void invalidatePrefix(String prefix) {
    _memory.removeWhere((key, _) => key.startsWith(prefix));
    if (isReady) {
      for (final key in _box!.keys.whereType<String>().toList()) {
        if (key.startsWith(prefix)) {
          _box!.delete(key);
        }
      }
    }
  }

  Future<void> clearAll() async {
    _memory.clear();
    _inFlight.clear();
    if (isReady) {
      await _box!.clear();
    }
  }
}

class _MemoryEntry {
  const _MemoryEntry(this.value, this.expiresAt);

  final Object? value;
  final DateTime expiresAt;
}
