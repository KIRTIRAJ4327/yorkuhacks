import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/geo_utils.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/location_provider.dart';
import '../widgets/map/safety_map.dart';

/// TACTICAL PANIC MODE - Emergency Extraction Screen
///
/// High-contrast UI optimized for stress situations:
/// - Large AR-style directional arrow pointing to safety
/// - Distance + ETA in huge text
/// - One-tap 911 call button
/// - Auto-routes to nearest police/hospital/24h store
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Keep screen on during emergency
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyProvider);
    final locationState = ref.watch(locationProvider);

    // Update distance as user moves
    if (locationState.position != null && emergencyState.isActive) {
      Future.microtask(() => ref
          .read(emergencyProvider.notifier)
          .updatePosition(locationState.position!));
    }

    // If arrived at safety, show success screen
    if (emergencyState.isActive &&
        emergencyState.distanceToSafety != null &&
        emergencyState.distanceToSafety! < 30) {
      return _buildArrivalScreen(context);
    }

    if (!emergencyState.isActive || emergencyState.targetSafeHarbor == null) {
      return _buildLoadingScreen();
    }

    final target = emergencyState.targetSafeHarbor!;
    final dist = emergencyState.distanceToSafety ?? 0;
    final eta = emergencyState.etaSeconds ?? 0;
    final userPos = locationState.position;

    // Calculate bearing to target (for AR arrow)
    final bearing = userPos != null
        ? GeoUtils.bearing(userPos, target.location)
        : 0.0;

    // Show ALL nearby safe spaces on the map (not just target)
    final safeSpacesToShow = emergencyState.allSafeSpaces.isNotEmpty
        ? emergencyState.allSafeSpaces
        : [target]; // Fallback to just target if list is empty

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Background map (dimmed) with safe space markers
          if (emergencyState.emergencyRoute != null && userPos != null)
            Opacity(
              opacity: 0.3,
              child: SafetyMap(
                controller: _mapController,
                center: userPos,
                zoom: 16,
                routes: [emergencyState.emergencyRoute!],
                selectedRouteIndex: 0,
                userLocation: userPos,
                safeSpaces: safeSpacesToShow, // Show all nearby safe harbors
                showSafeSpaces: true,
                isDark: true,
              ),
            ),

          // Pulsing highlight on TARGET safe harbor (on top of dimmed map)
          if (emergencyState.emergencyRoute != null && userPos != null)
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userPos,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none, // Disable interaction on overlay
                  ),
                ),
                children: [
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: target.location,
                        width: 80,
                        height: 80,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + _pulseController.value * 0.3;
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.yellow.withValues(
                                      alpha: 0.2 * (1 - _pulseController.value)),
                                  border: Border.all(
                                    color: Colors.yellow.withValues(
                                        alpha: 0.6 + _pulseController.value * 0.4),
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    target.type.emoji,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Main emergency UI
          SafeArea(
            child: Column(
              children: [
                // Header: EMERGENCY MODE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.red.withValues(alpha: 0.9),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'EMERGENCY EXTRACTION MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // AR Directional Arrow (HUGE)
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = 1.0 + _pulseController.value * 0.15;
                        return Transform.scale(
                          scale: scale,
                          child: Transform.rotate(
                            angle: bearing * math.pi / 180,
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 180,
                              color: Colors.yellow.withValues(
                                  alpha: 0.85 + _pulseController.value * 0.15),
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Distance + ETA (HUGE TEXT)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Text(
                        FormatUtils.formatDistance(dist),
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'to ${target.type.label}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(eta / 60).ceil()} MIN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Target info
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.yellow, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            target.type.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  target.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (target.address != null)
                                  Text(
                                    target.address!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (target.isOpen24h)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OPEN 24/7',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Call 911
                      Expanded(
                        child: _EmergencyButton(
                          label: 'CALL 911',
                          icon: Icons.phone,
                          color: Colors.red,
                          onPressed: () async {
                            final uri = Uri.parse('tel:911');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Exit emergency mode
                      Expanded(
                        child: _EmergencyButton(
                          label: 'EXIT',
                          icon: Icons.close,
                          color: Colors.white24,
                          textColor: Colors.white,
                          onPressed: () {
                            ref.read(emergencyProvider.notifier).deactivate();
                            context.go('/');
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFF000000),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.red, strokeWidth: 4),
            SizedBox(height: 20),
            Text(
              'FINDING NEAREST SAFE LOCATION...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 120,
              ),
              const SizedBox(height: 30),
              const Text(
                'YOU\'VE ARRIVED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You are now at a safe location.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(emergencyProvider.notifier).deactivate();
                    context.go('/');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Return to Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _EmergencyButton({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
