import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/colors.dart';

enum RouteType {
  fastest,
  balanced,
  safest;

  String get label {
    switch (this) {
      case fastest:
        return 'Fastest';
      case balanced:
        return 'Balanced';
      case safest:
        return 'Safest';
    }
  }

  String get emoji {
    switch (this) {
      case fastest:
        return '\u{1F3C3}';
      case balanced:
        return '\u{2696}\uFE0F';
      case safest:
        return '\u{1F6E1}\uFE0F';
    }
  }

  Color get color {
    switch (this) {
      case fastest:
        return AppColors.routeFastest;
      case balanced:
        return AppColors.routeBalanced;
      case safest:
        return AppColors.routeSafest;
    }
  }
}

class RouteSegment {
  final LatLng start;
  final LatLng end;
  final double safetyScore; // 0-100 for this segment

  const RouteSegment({
    required this.start,
    required this.end,
    required this.safetyScore,
  });

  Color get color => AppColors.forScore(safetyScore);
}

class RouteData {
  final String id;
  final List<LatLng> points;
  final List<RouteSegment> segments;
  final double distanceMeters;
  final int durationSeconds;
  final double safetyScore;
  final RouteType type;
  final String? aiSummary;

  // Safety breakdown
  final int crimesInBuffer;
  final double lightingCoverage; // 0-100
  final int collisionsNearby;
  final int safeSpacesCount;
  final bool hasSidewalk;

  const RouteData({
    required this.id,
    required this.points,
    this.segments = const [],
    required this.distanceMeters,
    required this.durationSeconds,
    required this.safetyScore,
    required this.type,
    this.aiSummary,
    this.crimesInBuffer = 0,
    this.lightingCoverage = 0,
    this.collisionsNearby = 0,
    this.safeSpacesCount = 0,
    this.hasSidewalk = true,
  });

  RouteData copyWith({
    String? id,
    double? safetyScore,
    RouteType? type,
    String? aiSummary,
    List<RouteSegment>? segments,
    int? crimesInBuffer,
    double? lightingCoverage,
    int? collisionsNearby,
    int? safeSpacesCount,
    bool? hasSidewalk,
  }) {
    return RouteData(
      id: id ?? this.id,
      points: points,
      segments: segments ?? this.segments,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      safetyScore: safetyScore ?? this.safetyScore,
      type: type ?? this.type,
      aiSummary: aiSummary ?? this.aiSummary,
      crimesInBuffer: crimesInBuffer ?? this.crimesInBuffer,
      lightingCoverage: lightingCoverage ?? this.lightingCoverage,
      collisionsNearby: collisionsNearby ?? this.collisionsNearby,
      safeSpacesCount: safeSpacesCount ?? this.safeSpacesCount,
      hasSidewalk: hasSidewalk ?? this.hasSidewalk,
    );
  }
}
