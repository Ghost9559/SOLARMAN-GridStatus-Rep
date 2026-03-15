import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _pollInterval = 5;
  String _stationId = '';
  String _deviceSn = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final interval = await StorageService.getPollInterval();
    final stationId = await StorageService.getStationId() ?? 'Not set';
    final deviceSn = await StorageService.getDeviceSn() ?? 'Not set';
    setState(() {
      _pollInterval = interval;
      _stationId = stationId;
      _deviceSn = deviceSn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Polling'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Poll Interval', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [5, 10, 15, 30].map((min) {
                    final selected = _pollInterval == min;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () async {
                          await StorageService.setPollInterval(min);
                          setState(() => _pollInterval = min);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF1E88E5) : const Color(0xFF1A1F2E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${min}m',
                            style: TextStyle(color: selected ? Colors.white : Colors.white54),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Device Info'),
          _buildCard(
            child: Column(
              children: [
                _infoRow('Station ID', _stationId),
                const Divider(color: Colors.white12, height: 24),
                _infoRow('Device S/N', _deviceSn),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Account'),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit, color: Colors.white54),
                  title: const Text('Update Credentials', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())).then((_) => _load()),
                ),
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Clear All Data', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF141824),
                        title: const Text('Clear Data?', style: TextStyle(color: Colors.white)),
                        content: const Text('This removes credentials and device info.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await StorageService.clearAll();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('About'),
          _buildCard(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Solarman Grid Monitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('v1.0.0', style: TextStyle(color: Colors.white38, fontSize: 12)),
                SizedBox(height: 8),
                Text(
                  'Monitors grid wire power via Solarman API and sends a single alert when grid goes down. Resets automatically when power is restored.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1.2)),
  );

  Widget _buildCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF141824),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  Widget _infoRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace')),
    ],
  );
}
