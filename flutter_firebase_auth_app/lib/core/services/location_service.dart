import 'dart:math';

class LocationUtils {
  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers

    // Convert degrees to radians
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c;

    return distance;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  /// Get distance text for display
  static String getDistanceText(
      double? currentLat,
      double? currentLng,
      double? otherLat,
      double? otherLng,
      ) {
    if (currentLat == null ||
        currentLng == null ||
        otherLat == null ||
        otherLng == null) {
      return 'Distance unknown';
    }

    final distance = calculateDistance(currentLat, currentLng, otherLat, otherLng);
    return formatDistance(distance);
  }
}