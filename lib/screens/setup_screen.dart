import 'package:flutter/material.dart';
import '../services/solarman_service.dart';
import '../services/storage_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appIdCtrl = TextEditingController();
  final _appSecretCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _step = '';
  bool _loading = false;
  bool _done = false;
  String _error = '';

  @override
  void dispose() {
    _appIdCtrl.dispose();
    _appSecretCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = ''; _done = false; });

    try {
      await StorageService.saveCredentials(
        appId: _appIdCtrl.text.trim(),
        appSecret: _appSecretCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      setState(() => _step = 'Getting access token...');
      await SolarmanService.getToken();

      setState(() => _step = 'Finding your station & device...');
      await SolarmanService.autoSetup();

      setState(() { _loading = false; _done = true; _step = 'Setup complete!'; });

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
        _step = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text('Setup', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.solar_power, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Solarman Credentials',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get these from the Solarman developer portal at\nhttps://home.solarmanpv.com',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 32),

              _buildField('App ID', _appIdCtrl, hint: 'Your API App ID'),
              const SizedBox(height: 16),
              _buildField('App Secret', _appSecretCtrl, hint: 'Your API App Secret'),
              const SizedBox(height: 16),
              _buildField('Email', _emailCtrl, hint: 'Solarman account email', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildField('Password', _passwordCtrl, hint: 'Solarman account password', obscure: true),
              const SizedBox(height: 32),

              // Info box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: const Text(
                  'After saving, the app will automatically find your station and inverter device. No manual station ID needed.',
                  style: TextStyle(color: Colors.lightBlue, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              if (_step.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      if (_loading)
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                        )
                      else
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_step, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                    ],
                  ),
                ),

              if (_error.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _setup,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save & Connect', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF141824),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E88E5)),
            ),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }
}
