import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../providers/emergency_provider.dart';

/// Emergency SOS button.
/// Single tap shows emergency options. Hold 2s to activate PANIC MODE.
class SOSButton extends ConsumerStatefulWidget {
  /// If true, shows a compact version (for embedding in app bars etc)
  final bool compact;

  const SOSButton({super.key, this.compact = false});

  @override
  ConsumerState<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends ConsumerState<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_triggered) {
        _triggered = true;
        HapticFeedback.heavyImpact();
        _activatePanicMode(); // PANIC MODE on long-press complete
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emergency, color: AppColors.dangerAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Emergency SOS',
              style: TextStyle(
                color: AppColors.dangerAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose an emergency action:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // PANIC MODE (new primary action)
            _EmergencyOption(
              icon: Icons.emergency_outlined,
              label: 'Activate Panic Mode',
              subtitle: 'Auto-route to nearest safe location',
              color: Colors.red,
              onTap: () {
                Navigator.pop(ctx);
                _activatePanicMode();
              },
            ),
            const SizedBox(height: 12),
            // Call 911
            _EmergencyOption(
              icon: Icons.phone,
              label: 'Call 911',
              subtitle: 'Connect to emergency services',
              color: AppColors.dangerAccent,
              onTap: () {
                Navigator.pop(ctx);
                _callEmergency();
              },
            ),
            const SizedBox(height: 12),
            // Call non-emergency
            _EmergencyOption(
              icon: Icons.local_police_outlined,
              label: 'York Regional Police',
              subtitle: 'Non-emergency: 1-866-876-5423',
              color: AppColors.alertAccent,
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('tel:18668765423');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    ).then((_) => _triggered = false);
  }

  /// Activate TACTICAL PANIC MODE - routes to nearest police/hospital/24h store
  Future<void> _activatePanicMode() async {
    await ref.read(emergencyProvider.notifier).activatePanicMode();
    if (mounted) {
      context.push('/emergency');
    }
  }

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:911');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 44.0 : 56.0;
    final fontSize = widget.compact ? 11.0 : 14.0;

    return GestureDetector(
      // Single tap → show emergency options dialog
      onTap: () {
        HapticFeedback.mediumImpact();
        _showSOSDialog();
      },
      // Long press → direct 911 call
      onLongPressStart: (_) {
        _controller.forward(from: 0);
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) {
        if (!_triggered) {
          _controller.reset();
        }
      },
      onLongPressCancel: () {
        if (!_triggered) {
          _controller.reset();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                const Color(0xFF1E293B),
                AppColors.dangerAccent,
                _controller.value,
              ),
              border: Border.all(
                color: AppColors.dangerAccent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.dangerAccent
                      .withValues(alpha: 0.3 + _controller.value * 0.4),
                  blurRadius: 8 + 12 * _controller.value,
                  spreadRadius: 2 * _controller.value,
                ),
              ],
            ),
            child: Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Individual emergency option row
class _EmergencyOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _EmergencyOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
