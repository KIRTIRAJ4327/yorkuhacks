import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants.dart';
import '../../../core/theme/colors.dart';
import '../../../data/models/route_data.dart';
import '../../../data/models/safe_space.dart';

/// Main map widget with dark tiles, route polylines, and markers
class SafetyMap extends StatelessWidget {
  final MapController? controller;
  final LatLng center;
  final double zoom;
  final List<RouteData> routes;
  final int? selectedRouteIndex;
  final LatLng? userLocation;
  final List<SafeSpace> safeSpaces;
  final bool showSafeSpaces;
  final bool isDark;

  const SafetyMap({
    super.key,
    this.controller,
    required this.center,
    this.zoom = AppConstants.defaultZoom,
    this.routes = const [],
    this.selectedRouteIndex,
    this.userLocation,
    this.safeSpaces = const [],
    this.showSafeSpaces = true,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        maxZoom: 18,
        minZoom: 10,
      ),
      children: [
        // Tile layer (dark or light)
        TileLayer(
          urlTemplate: isDark
              ? AppConstants.darkTileUrl
              : AppConstants.lightTileUrl,
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.safepath.yorkuhack',
        ),

        // Route polylines (unselected routes first, selected on top)
        if (routes.isNotEmpty) ...[
          // Draw unselected routes (dimmed)
          PolylineLayer(
            polylines: routes
                .asMap()
                .entries
                .where((e) => e.key != selectedRouteIndex)
                .map((entry) => Polyline(
                      points: entry.value.points,
                      strokeWidth: 4,
                      color:
                          entry.value.type.color.withValues(alpha: 0.3),
                    ))
                .toList(),
          ),

          // Draw selected route segments (color-coded)
          if (selectedRouteIndex != null &&
              selectedRouteIndex! < routes.length)
            _buildSelectedRoute(routes[selectedRouteIndex!]),
        ],

        // Safe space markers
        if (showSafeSpaces && safeSpaces.isNotEmpty)
          MarkerLayer(
            markers: safeSpaces
                .map((space) => Marker(
                      point: space.location,
                      width: 36,
                      height: 36,
                      child: Tooltip(
                        message: space.name,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.safeAccent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              space.type.emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

        // User location marker
        if (userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userLocation!,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSelectedRoute(RouteData route) {
    if (route.segments.isNotEmpty) {
      // Color-coded segments
      return PolylineLayer(
        polylines: route.segments
            .map((seg) => Polyline(
                  points: [seg.start, seg.end],
                  strokeWidth: 6,
                  color: seg.color,
                ))
            .toList(),
      );
    }

    // Fallback: solid color
    return PolylineLayer(
      polylines: [
        Polyline(
          points: route.points,
          strokeWidth: 6,
          color: route.type.color,
        ),
      ],
    );
  }
}
