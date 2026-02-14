/// Breakdown of a safety score calculation
class SafetyScore {
  final double overall; // 0-100
  final double crimeScore; // 0-100
  final double lightingScore; // 0-100
  final double collisionScore; // 0-100
  final double safeSpaceScore; // 0-100
  final double infraScore; // 0-100

  const SafetyScore({
    required this.overall,
    required this.crimeScore,
    required this.lightingScore,
    required this.collisionScore,
    required this.safeSpaceScore,
    required this.infraScore,
  });

  Map<String, double> get breakdown => {
        'Crime Safety': crimeScore,
        'Lighting': lightingScore,
        'Collision Safety': collisionScore,
        'Safe Spaces': safeSpaceScore,
        'Infrastructure': infraScore,
      };
}
