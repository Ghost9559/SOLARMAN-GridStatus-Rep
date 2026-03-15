import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class SolarmanService {
  static const String _baseUrl = 'https://globalapi.solarmanpv.com';

  // ─── STEP 1: Get Access Token ─────────────────────────────────────────────
  static Future<String> getToken() async {
    // Return cached token if still valid
    final cached = await StorageService.getValidToken();
    if (cached != null) return cached;

    final creds = await StorageService.getCredentials();
    final appId = creds['app_id']!;
    final appSecret = creds['app_secret']!;
    final email = creds['email']!;
    final password = creds['password']!;

    // Solarman requires password as MD5 hash
    final hashedPassword = md5.convert(utf8.encode(password)).toString();

    final url = Uri.parse(
      '$_baseUrl/account/v1.0/token?appId=$appId&language=en',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'appSecret': appSecret,
        'email': email,
        'password': hashedPassword,
      }),
    );

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception('Auth failed: ${data['msg'] ?? 'Unknown error'}');
    }

    final token = data['access_token'] as String;
    // Token typically valid for 2 hours, we cache for 1.5h to be safe
    final expiry = DateTime.now().add(const Duration(minutes: 90));
    await StorageService.saveToken(token, expiry);

    return token;
  }

  // ─── STEP 2: Get Station List ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getStations() async {
    final token = await getToken();

    final response = await http.post(
      Uri.parse('$_baseUrl/station/v1.0/list?language=en'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'page': 1, 'size': 20}),
    );

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception('Failed to get stations: ${data['msg']}');
    }

    final stationList = data['stationList'] as List<dynamic>? ?? [];
    return stationList.cast<Map<String, dynamic>>();
  }

  // ─── STEP 3: Get Device List ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDevices(String stationId) async {
    final token = await getToken();

    final response = await http.post(
      Uri.parse('$_baseUrl/device/v1.0/list?language=en'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'stationId': stationId, 'page': 1, 'size': 20}),
    );

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception('Failed to get devices: ${data['msg']}');
    }

    final deviceList = data['deviceListItems'] as List<dynamic>? ?? [];
    return deviceList.cast<Map<String, dynamic>>();
  }

  // ─── STEP 4: Get Realtime Data ────────────────────────────────────────────
  static Future<SolarData> getRealtimeData() async {
    final token = await getToken();
    final deviceSn = await StorageService.getDeviceSn();

    if (deviceSn == null) {
      throw Exception('No device configured. Go to Setup.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/device/v1.0/realtime?language=en'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'deviceSn': deviceSn}),
    );

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception('Failed to get realtime data: ${data['msg']}');
    }

    return SolarData.fromApi(data);
  }

  // ─── Auto-setup: fetch station + device automatically ─────────────────────
  static Future<void> autoSetup() async {
    final stations = await getStations();
    if (stations.isEmpty) throw Exception('No stations found in your account.');

    // Use first station
    final stationId = stations[0]['id'].toString();

    final devices = await getDevices(stationId);
    if (devices.isEmpty) throw Exception('No devices found in station.');

    // Use first inverter device
    final device = devices.firstWhere(
      (d) => d['deviceType'] == 'INVERTER',
      orElse: () => devices[0],
    );
    final deviceSn = device['deviceSn'].toString();

    await StorageService.saveStationAndDevice(stationId, deviceSn);
  }
}

// ─── Data Model ──────────────────────────────────────────────────────────────
class SolarData {
  final double wirePower;       // Grid power (W) — 0 means grid is OFF
  final double solarPower;      // PV generation (W)
  final double batteryPower;    // Battery power (W, negative = charging)
  final int batterySoc;         // Battery state of charge (%)
  final double loadPower;       // Total home load (W)
  final DateTime fetchedAt;
  final String rawStatus;

  SolarData({
    required this.wirePower,
    required this.solarPower,
    required this.batteryPower,
    required this.batterySoc,
    required this.loadPower,
    required this.fetchedAt,
    required this.rawStatus,
  });

  bool get isGridDown => wirePower <= 0;

  factory SolarData.fromApi(Map<String, dynamic> data) {
    final dataList = data['dataList'] as List<dynamic>? ?? [];
    
    double getValue(String key) {
      final item = dataList.firstWhere(
        (d) => d['key'] == key,
        orElse: () => {'value': '0'},
      );
      return double.tryParse(item['value']?.toString() ?? '0') ?? 0.0;
    }

    return SolarData(
      wirePower: getValue('W_totalGridPower'),      // or 'pG' or 'gridPower'
      solarPower: getValue('W_totalDcPower'),
      batteryPower: getValue('W_batteryPower'),
      batterySoc: getValue('SOC').toInt(),
      loadPower: getValue('W_totalLoadPower'),
      fetchedAt: DateTime.now(),
      rawStatus: data['deviceState']?.toString() ?? 'unknown',
    );
  }

  // Empty state for when no data yet
  factory SolarData.empty() => SolarData(
    wirePower: 0,
    solarPower: 0,
    batteryPower: 0,
    batterySoc: 0,
    loadPower: 0,
    fetchedAt: DateTime.now(),
    rawStatus: 'none',
  );
}
