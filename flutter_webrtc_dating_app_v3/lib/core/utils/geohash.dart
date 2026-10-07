import 'dart:math' as math;

/// Minimal geohash encode/decode. Discovery publishes precision 5
/// (a cell of about 4.9 x 4.9 km), never raw coordinates.
/// Same algorithm as functions/profile_mirror.js.
class Geohash {
  Geohash._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Precision used for public profiles.
  static const int publicPrecision = 5;

  static String encode(double lat, double lng,
      {int precision = publicPrecision}) {
    var latMin = -90.0, latMax = 90.0;
    var lngMin = -180.0, lngMax = 180.0;
    final out = StringBuffer();
    var bit = 0, ch = 0;
    var even = true;
    while (out.length < precision) {
      if (even) {
        final mid = (lngMin + lngMax) / 2;
        if (lng >= mid) {
          ch = (ch << 1) | 1;
          lngMin = mid;
        } else {
          ch <<= 1;
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (lat >= mid) {
          ch = (ch << 1) | 1;
          latMin = mid;
        } else {
          ch <<= 1;
          latMax = mid;
        }
      }
      even = !even;
      if (++bit == 5) {
        out.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return out.toString();
  }

  /// Centre of the cell, or null for an invalid hash.
  static ({double lat, double lng})? decode(String? hash) {
    if (hash == null || hash.isEmpty) return null;
    var latMin = -90.0, latMax = 90.0;
    var lngMin = -180.0, lngMax = 180.0;
    var even = true;
    for (final c in hash.toLowerCase().split('')) {
      final idx = _base32.indexOf(c);
      if (idx < 0) return null;
      for (var i = 4; i >= 0; i--) {
        final bitOn = (idx >> i) & 1 == 1;
        if (even) {
          final mid = (lngMin + lngMax) / 2;
          if (bitOn) {
            lngMin = mid;
          } else {
            lngMax = mid;
          }
        } else {
          final mid = (latMin + latMax) / 2;
          if (bitOn) {
            latMin = mid;
          } else {
            latMax = mid;
          }
        }
        even = !even;
      }
    }
    return (lat: (latMin + latMax) / 2, lng: (lngMin + lngMax) / 2);
  }

  /// Height and width in degrees of a cell at [precision].
  static ({double lat, double lng}) cellSize(int precision) {
    final bits = precision * 5;
    final lngBits = (bits + 1) ~/ 2;
    final latBits = bits ~/ 2;
    return (
      lat: 180 / math.pow(2, latBits),
      lng: 360 / math.pow(2, lngBits),
    );
  }

  /// [hash] and its 8 surrounding cells (fewer next to the poles), for
  /// prefix range queries that cover "nearby" without exact coordinates.
  static List<String> withNeighbors(String hash) {
    final centre = decode(hash);
    if (centre == null) return const [];
    final size = cellSize(hash.length);
    final out = <String>{};
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final lat = centre.lat + dy * size.lat;
        if (lat <= -90 || lat >= 90) continue;
        var lng = centre.lng + dx * size.lng;
        if (lng >= 180) lng -= 360;
        if (lng < -180) lng += 360;
        out.add(encode(lat, lng, precision: hash.length));
      }
    }
    return out.toList();
  }

  /// Great-circle distance in km.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Distance rounded up to the next 5 km bucket (5, 10, 15 ...), so the
  /// displayed value never narrows a user down beyond the cell size.
  static int approxDistanceKm(double lat1, double lng1, String? otherHash) {
    final other = decode(otherHash);
    if (other == null) return -1;
    final d = distanceKm(lat1, lng1, other.lat, other.lng);
    final bucket = (d / 5).ceil() * 5;
    return bucket < 5 ? 5 : bucket;
  }
}
