import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format_utils.dart';
import '../../data/models/route_data.dart' as models;
import '../../providers/location_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/route_provider.dart';
import '../widgets/map/safety_map.dart';
import '../widgets/navigation/sos_button.dart';

class RouteSelectionScreen extends ConsumerStatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  ConsumerState<RouteSelectionScreen> createState() =>
      _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends ConsumerState<RouteSelectionScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final locationState = ref.watch(locationProvider);
    final routes = routeState.routes;
    final screenH = MediaQuery.of(context).size.height;

    if (routes.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(destinationName: null, onBack: () => context.pop()),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, color: AppColors.textSecondary, size: 48),
                      SizedBox(height: 16),
                      Text('No routes found',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selected = routes[routeState.selectedIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ===== MAP (top 50%) =====
          SizedBox(
            height: screenH * 0.50,
            child: Stack(
              children: [
                SafetyMap(
                  controller: _mapController,
                  center: selected.points.isNotEmpty
                      ? selected.points[selected.points.length ~/ 2]
                      : locationState.position!,
                  zoom: 14,
                  routes: routes,
                  selectedRouteIndex: routeState.selectedIndex,
                  userLocation: locationState.position,
                  isDark: true,
                ),
                // Back + destination
                _TopBar(
                  destinationName: routeState.destinationName,
                  onBack: () => context.pop(),
                ),
                // SOS (bottom-left of map)
                const Positioned(
                  bottom: 16,
                  left: 16,
                  child: SOSButton(compact: true),
                ),
              ],
            ),
          ),

          // ===== ROUTE PANEL (bottom 50%) =====
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF162032),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Tabs
                  _RouteTabs(
                    routes: routes,
                    selectedIndex: routeState.selectedIndex,
                    onTap: (i) => ref.read(routeProvider.notifier).selectRoute(i),
                  ),

                  const SizedBox(height: 8),

                  // Card (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: _CompactCard(
                        route: selected,
                        onStart: () {
                          ref.read(navigationProvider.notifier).startNavigation(selected);
                          context.push('/navigate');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ──
class _TopBar extends StatelessWidget {
  final String? destinationName;
  final VoidCallback onBack;

  const _TopBar({required this.destinationName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Material(
              color: AppColors.surface.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (destinationName != null)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: AppColors.brand, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          destinationName!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Route type tabs ──
class _RouteTabs extends StatelessWidget {
  final List<models.RouteData> routes;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _RouteTabs({required this.routes, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: List.generate(routes.length, (i) {
            final r = routes[i];
            final active = i == selectedIndex;
            final c = r.type.color;

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: active ? c.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: active ? Border.all(color: c.withValues(alpha: 0.3)) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(r.type.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            r.type.label,
                            style: TextStyle(
                              color: active ? c : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r.safetyScore.round()}/100',
                        style: TextStyle(
                          color: active
                              ? AppColors.forScore(r.safetyScore)
                              : AppColors.textSecondary.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Compact route card ──
class _CompactCard extends StatelessWidget {
  final models.RouteData route;
  final VoidCallback onStart;

  const _CompactCard({required this.route, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final c = route.type.color;
    final sc = AppColors.forScore(route.safetyScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: type badge + time/distance
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(route.type.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text(
                      route.type.label.toUpperCase(),
                      style: TextStyle(
                        color: c, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                FormatUtils.formatDuration(route.durationSeconds),
                style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                FormatUtils.formatDistance(route.distanceMeters),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Score arc + 4 stats in a compact row
          Row(
            children: [
              // Score circle (small)
              SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: _ArcPainter(score: route.safetyScore, color: sc),
                  child: Center(
                    child: Text(
                      '${route.safetyScore.round()}',
                      style: TextStyle(
                        color: sc, fontSize: 20, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Stats: 2×2 grid
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _Chip(Icons.lightbulb_outline, '${route.lightingCoverage.round()}% Lit',
                        AppColors.alertAccent),
                    _Chip(Icons.local_hospital_outlined, '${route.safeSpacesCount} Safe',
                        AppColors.safeAccent),
                    _Chip(Icons.warning_amber_outlined, '${route.crimesInBuffer} Crime',
                        route.crimesInBuffer > 3 ? AppColors.dangerAccent : AppColors.textSecondary),
                    _Chip(Icons.car_crash_outlined, '${route.collisionsNearby} Crash',
                        route.collisionsNearby > 3 ? AppColors.dangerAccent : AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),

          // AI summary (if available)
          if (route.aiSummary != null && route.aiSummary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.brand.withValues(alpha: 0.7), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      route.aiSummary!,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: c,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.navigation_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Start Navigation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ──
class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Chip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Score arc painter ──
class _ArcPainter extends CustomPainter {
  final double score;
  final Color color;
  _ArcPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      (score / 100) * math.pi * 1.5,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.score != score || old.color != color;
}
