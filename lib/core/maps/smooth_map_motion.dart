import 'dart:async';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class SmoothMapMotion {
  Timer? _timer;

  void move({
    required LatLng? from,
    required LatLng to,
    required void Function(LatLng position, double bearing) onUpdate,
    Duration duration = const Duration(milliseconds: 900),
  }) {
    _timer?.cancel();
    final start = from ?? to;
    if (start == to) {
      onUpdate(to, 0);
      return;
    }

    final bearing = bearingBetween(start, to);
    final startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      final progress = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - progress, 3).toDouble();
      onUpdate(
        LatLng(
          start.latitude + (to.latitude - start.latitude) * eased,
          start.longitude + (to.longitude - start.longitude) * eased,
        ),
        bearing,
      );
      if (progress >= 1) timer.cancel();
    });
  }

  static double bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final deltaLongitude = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(deltaLongitude) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static LatLng? locationFromPayload(dynamic payload) {
    var value = payload is List && payload.isNotEmpty ? payload.first : payload;
    if (value is! Map) return null;
    if (value['location'] is Map) {
      value = value['location'];
    } else if (value['currentLocation'] is Map) {
      value = value['currentLocation'];
    } else if (value['driverLocation'] is Map) {
      value = value['driverLocation'];
    }
    final latitude = double.tryParse(
      (value['latitude'] ?? value['lat'])?.toString() ?? '',
    );
    final longitude = double.tryParse(
      (value['longitude'] ?? value['lng'] ?? value['lon'])?.toString() ?? '',
    );
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return LatLng(latitude, longitude);
  }

  static List<LatLng> routeFromPayload(dynamic payload) {
    if (payload is! Map) return const [];
    if (payload['booking'] is Map) {
      final nested = routeFromPayload(payload['booking']);
      if (nested.isNotEmpty) return nested;
    }
    final route = payload['route'];
    final encoded = route is Map
        ? route['polyline']
        : payload['routePolyline'] ?? payload['polyline'];
    if (encoded is! String || encoded.isEmpty) return const [];
    return decodePolyline(encoded);
  }

  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  static LatLngBounds? boundsFor(Iterable<LatLng> points) {
    if (points.isEmpty) return null;
    var minLat = 90.0;
    var maxLat = -90.0;
    var minLng = 180.0;
    var maxLng = -180.0;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void dispose() => _timer?.cancel();
}
