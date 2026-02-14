import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';

/// Emergency SOS button (long-press 2s to trigger)
class SOSButton extends StatefulWidget {
  const SOSButton({super.key});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
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
        _showSOSDialog();
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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('\u{1F6A8}', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Emergency SOS',
              style: TextStyle(color: AppColors.dangerAccent),
            ),
          ],
        ),
        content: const Text(
          'Call 911 or share your location with emergency contacts?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _triggered = false;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('tel:911');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('Call 911'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ).then((_) => _triggered = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                AppColors.surface,
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
                      .withValues(alpha: _controller.value * 0.5),
                  blurRadius: 12 * _controller.value,
                  spreadRadius: 4 * _controller.value,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
