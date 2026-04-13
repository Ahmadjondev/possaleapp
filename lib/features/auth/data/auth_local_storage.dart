import 'package:shared_preferences/shared_preferences.dart';

/// Handles local storage of JWT tokens and session metadata.
class AuthLocalStorage {
  static const _accessTokenKey = 'pos_access_token';
  static const _refreshTokenKey = 'pos_refresh_token';
  static const _serverUrlKey = 'pos_server_url';
  static const _lastPinVerifiedKey = 'pos_last_pin_verified';
  static const _currentUserKey = 'pos_current_user';
  static const _warehouseKey = 'pos_selected_warehouse_id';

  final SharedPreferences _prefs;

  AuthLocalStorage({required SharedPreferences prefs}) : _prefs = prefs;

  // --- Tokens ---

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _prefs.setString(_accessTokenKey, access);
    await _prefs.setString(_refreshTokenKey, refresh);
  }

  Future<String?> getAccessToken() async => _prefs.getString(_accessTokenKey);
  Future<String?> getRefreshToken() async => _prefs.getString(_refreshTokenKey);

  Future<void> clearTokens() async {
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
  }

  // --- Warehouse ---

  Future<void> saveWarehouseId(int id) async {
    await _prefs.setInt(_warehouseKey, id);
  }

  int? getWarehouseId() => _prefs.getInt(_warehouseKey);

  // --- Server URL ---

  Future<void> saveServerUrl(String url) async {
    await _prefs.setString(_serverUrlKey, url);
  }

  String? getServerUrl() => _prefs.getString(_serverUrlKey);

  // --- PIN Verification Tracking ---

  Future<void> savePinVerifiedTimestamp() async {
    await _prefs.setString(
      _lastPinVerifiedKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Returns true if PIN was verified today (same calendar date).
  bool isPinVerifiedToday() {
    final stored = _prefs.getString(_lastPinVerifiedKey);
    if (stored == null) return false;
    final lastVerified = DateTime.tryParse(stored);
    if (lastVerified == null) return false;
    final now = DateTime.now();
    return lastVerified.year == now.year &&
        lastVerified.month == now.month &&
        lastVerified.day == now.day;
  }

  Future<void> clearPinVerification() async {
    await _prefs.remove(_lastPinVerifiedKey);
  }

  // --- Current User JSON ---

  Future<void> saveCurrentUser(String userJson) async {
    await _prefs.setString(_currentUserKey, userJson);
  }

  String? getCurrentUser() => _prefs.getString(_currentUserKey);

  Future<void> clearCurrentUser() async {
    await _prefs.remove(_currentUserKey);
  }

  // --- Full Clear ---

  Future<void> clearAll() async {
    await clearTokens();
    await clearPinVerification();
    await clearCurrentUser();
  }
}
