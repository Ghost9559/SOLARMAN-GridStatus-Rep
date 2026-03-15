import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/solarman_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SolarData _data = SolarData.empty();
  String _status = 'Idle';
  String _error = '';
  bool _loading = false;
  bool _hasSetup = false;
  Timer? _pollTimer;
  int _pollInterval = 5; // minutes
  DateTime? _lastFetch;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _hasSetup = await StorageService.getDeviceSn() != null;
    _pollInterval = await StorageService.getPollInterval();
    if (_hasSetup) {
      await _fetchData();
      _startPolling();
    }
    if (mounted) setState(() {});
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(minutes: _pollInterval),
      (_) => _fetchData(),
    );
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = _pollInterval * 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _status = 'Fetching...';
      _error = '';
    });

    try {
      final data = await SolarmanService.getRealtimeData();
      await StorageService.setLastWirePower(data.wirePower);

      // ─── STATE FLAG LOGIC (replaces MacroDroid latch) ───────────────────
      final alertAlreadySent = await StorageService.getGridAlertSent();

      if (data.isGridDown && !alertAlreadySent) {
        // Grid just went down — alert ONCE
        await NotificationService.sendGridDownAlert();
        await StorageService.setGridAlertSent(true);
      } else if (!data.isGridDown && alertAlreadySent) {
        // Grid restored — reset flag + notify
        await NotificationService.sendGridRestoredAlert();
        await StorageService.setGridAlertSent(false);
      }
      // else: grid still down & already alerted → do nothing (no duplicates)
      // ─────────────────────────────────────────────────────────────────────

      if (mounted) {
        setState(() {
          _data = data;
          _lastFetch = DateTime.now();
          _status = data.isGridDown ? '⚠ Grid Down' : '✓ Online';
          _loading = false;
        });
      }
      _startCountdown();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _status = 'Error';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text(
          'Solar Monitor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _init();
            },
          ),
        ],
      ),
      body: !_hasSetup
          ? _buildSetupPrompt()
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildGridCard(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard('Solar', '${_data.solarPower.toInt()}W', Icons.wb_sunny, Colors.orange)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildBatteryCard()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMetricCard('Home Load', '${_data.loadPower.toInt()}W', Icons.home, Colors.blueAccent, wide: true),
                    const SizedBox(height: 12),
                    _buildInfoCard(),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildErrorCard(),
                    ],
                  ],
                ),
              ),
            ),
      floatingActionButton: _hasSetup
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1E88E5),
              onPressed: _loading ? null : _fetchData,
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            )
          : null,
    );
  }

  Widget _buildSetupPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.solar_power, size: 80, color: Colors.orange),
          const SizedBox(height: 20),
          const Text(
            'Setup Required',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your Solarman credentials to get started',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SetupScreen()),
              );
              await _init();
            },
            child: const Text('Setup Now', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isDown = _data.isGridDown;
    final color = isDown ? Colors.red : Colors.greenAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDown ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(isDown ? Icons.power_off : Icons.bolt, color: color, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDown ? 'GRID DOWN' : 'GRID ONLINE',
                style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (_lastFetch != null)
                Text(
                  'Last update: ${DateFormat('HH:mm:ss').format(_lastFetch!)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
          const Spacer(),
          if (_countdown > 0)
            Column(
              children: [
                Text(
                  '${_countdown}s',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const Text('next poll', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGridCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wire Power (Grid)', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '${_data.wirePower.toInt()} W',
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard() {
    final soc = _data.batterySoc;
    final color = soc > 50 ? Colors.greenAccent : soc > 20 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.battery_charging_full, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            '$soc%',
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Text('Battery', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, {bool wide = false}) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.white38, size: 18),
          const SizedBox(width: 8),
          Text(
            'Polling every $_pollInterval min',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const Spacer(),
          const Icon(Icons.notifications_active, color: Colors.white38, size: 18),
          const SizedBox(width: 4),
          const Text('Outage alerts on', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        'Error: $_error',
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}
