import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class LocalStoreService {
  static const _storageKey = 'andrews_supermarket_demo_state_v2';

  Future<PersistedData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return PersistedData.fromJson(raw);
  }

  Future<void> save(PersistedData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, data.toJson());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
