import 'package:flutter/material.dart';

import 'sms_scan_screen.dart';
import 'scan_screen.dart';
import 'url_scan_screen.dart';

import '../services/sms_background_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAutoProtectEnabled = false;

  void _toggleAutoProtect(bool value) async {
    if (value) {
      await SmsBackgroundService().init();
      setState(() {
        _isAutoProtectEnabled = true;
      });
    } else {
      // In a real app, you would unregister the listener or pause it.
      setState(() {
        _isAutoProtectEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeScan'),
        actions: [
          IconButton(
            onPressed: () => _showAbout(context),
            tooltip: 'About SafeScan',
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'A calmer way to check what you receive.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Scan apps, messages, and links for suspicious signals before you trust them.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D5F58)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Your first line of defense',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Automatic SMS Protection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan incoming messages in the background',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAutoProtectEnabled,
                    onChanged: _toggleAutoProtect,
                    activeColor: const Color(0xFF0F766E),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              const Text(
                'Choose a scan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _ScannerCard(
                icon: Icons.android_rounded,
                title: 'Scan an APK',
                subtitle: 'Check an Android app before installing it.',
                iconBgColor: const Color(0xFF0F766E).withOpacity(0.2),
                iconColor: const Color(0xFF80D5CB),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ScannerCard(
                icon: Icons.sms_rounded,
                title: 'Scan an SMS',
                subtitle: 'Spot suspicious messages and scam language.',
                iconBgColor: const Color(0xFFB45309).withOpacity(0.2),
                iconColor: const Color(0xFFFCD34D),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmsScanScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ScannerCard(
                icon: Icons.link_rounded,
                title: 'Scan a URL',
                subtitle: 'Check a link before opening the website.',
                iconBgColor: const Color(0xFF4338CA).withOpacity(0.2),
                iconColor: const Color(0xFFA5B4FC),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UrlScanScreen()),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'SafeScan provides automated security analysis. '
                'Results should be treated as an indication, not a guarantee.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'SafeScan',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.shield_rounded),
      children: const [
        Text(
          'Scan apps, messages, and links for suspicious signals. '
          'Results are automated indicators, not guarantees of safety.',
        ),
      ],
    );
  }
}

class _ScannerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ScannerCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
