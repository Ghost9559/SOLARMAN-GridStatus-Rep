import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyAppId = 'app_id';
  static const _keyAppSecret = 'app_secret';
  static const _keyEmail = 'email';
  static const _keyPassword = 'password';
  static const _keyToken = 'access_token';
  static const _keyTokenExpiry = 'token_expiry';
  static const _keyStationId = 'station_id';
  static const _keyDeviceSn = 'device_sn';
  static const _keyPollInterval = 'poll_interval';
  static const _keyGridAlertSent = 'grid_alert_sent'; // STATE FLAG
  static const _keyLastWirePower = 'last_wire_power';

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // Credentials
  static Future<void> saveCredentials({
    required String appId,
    required String appSecret,
    required String email,
    required String password,
  }) async {
    final p = await _prefs;
    await p.setString(_keyAppId, appId);
    await p.setString(_keyAppSecret, appSecret);
    await p.setString(_keyEmail, email);
    await p.setString(_keyPassword, password);
  }

  static Future<Map<String, String>> getCredentials() async {
    final p = await _prefs;
    return {
      'app_id': p.getString(_keyAppId) ?? '',
      'app_secret': p.getString(_keyAppSecret) ?? '',
      'email': p.getString(_keyEmail) ?? '',
      'password': p.getString(_keyPassword) ?? '',
    };
  }

  static Future<bool> hasCredentials() async {
    final creds = await getCredentials();
    return creds.values.every((v) => v.isNotEmpty);
  }

  // Token
  static Future<void> saveToken(String token, DateTime expiry) async {
    final p = await _prefs;
    await p.setString(_keyToken, token);
    await p.setString(_keyTokenExpiry, expiry.toIso8601String());
  }

  static Future<String?> getValidToken() async {
    final p = await _prefs;
    final token = p.getString(_keyToken);
    final expiryStr = p.getString(_keyTokenExpiry);
    if (token == null || expiryStr == null) return null;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null || DateTime.now().isAfter(expiry)) return null;
    return token;
  }

  // Station & Device
  static Future<void> saveStationAndDevice(String stationId, String deviceSn) async {
    final p = await _prefs;
    await p.setString(_keyStationId, stationId);
    await p.setString(_keyDeviceSn, deviceSn);
  }

  static Future<String?> getStationId() async =>
      (await _prefs).getString(_keyStationId);

  static Future<String?> getDeviceSn() async =>
      (await _prefs).getString(_keyDeviceSn);

  // Poll interval (minutes)
  static Future<void> setPollInterval(int minutes) async =>
      (await _prefs).setInt(_keyPollInterval, minutes);

  static Future<int> getPollInterval() async =>
      (await _prefs).getInt(_keyPollInterval) ?? 5;

  // ─── STATE FLAG ───────────────────────────────────────────────────────────
  // This is the fix for the MacroDroid duplicate alert problem.
  // grid_alert_sent = true means we already alerted, don't fire again.
  // It resets when power comes back.

  static Future<void> setGridAlertSent(bool value) async =>
      (await _prefs).setBool(_keyGridAlertSent, value);

  static Future<bool> getGridAlertSent() async =>
      (await _prefs).getBool(_keyGridAlertSent) ?? false;

  // Last wire power reading (for display)
  static Future<void> setLastWirePower(double value) async =>
      (await _prefs).setDouble(_keyLastWirePower, value);

  static Future<double> getLastWirePower() async =>
      (await _prefs).getDouble(_keyLastWirePower) ?? 0.0;

  // Clear all saved data
  static Future<void> clearAll() async => (await _prefs).clear();
}
