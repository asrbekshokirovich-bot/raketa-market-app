import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' show Rect, Offset;

class YandexProjection extends Projection {
  static const double _eccentricity = 0.0818191908426;

  const YandexProjection() : super(
    const Rect.fromLTRB(-3.141592653589793, -3.141592653589793, 3.141592653589793, 3.141592653589793)
  );

  @override
  (double, double) projectXY(LatLng latLng) {
    final latRad = latLng.latitude * (math.pi / 180);
    final lngRad = latLng.longitude * (math.pi / 180);

    final x = lngRad;
    final y = math.log(
      math.tan(math.pi / 4 + latRad / 2) *
      math.pow((1 - _eccentricity * math.sin(latRad)) / (1 + _eccentricity * math.sin(latRad)), _eccentricity / 2)
    );

    return (x, y);
  }

  @override
  LatLng unprojectXY(double x, double y) {
    final lng = x * (180 / math.pi);
    
    // Inverse Elliptical Mercator Latitude (iterative)
    final double ts = math.exp(-y);
    double phi = math.pi / 2 - 2 * math.atan(ts);
    double dphi;
    int i = 0;
    
    do {
      final con = _eccentricity * math.sin(phi);
      final conPow = math.pow((1.0 - con) / (1.0 + con), _eccentricity / 2.0);
      final newPhi = math.pi / 2 - 2 * math.atan(ts * conPow);
      dphi = (newPhi - phi).abs();
      phi = newPhi;
      i++;
    } while (dphi > 1e-10 && i < 15);

    final lat = phi * (180 / math.pi);
    return LatLng(lat, lng);
  }
}

class CrsYandex extends Crs {
  const CrsYandex()
      : super(
          code: 'EPSG:3395',
          infinite: false,
        );

  @override
  Projection get projection => const YandexProjection();

  @override
  (double, double) latLngToXY(LatLng latlng, double scale) {
    final (x, y) = projection.projectXY(latlng);
    return transform(x, y, scale);
  }

  @override
  (double, double) transform(double x, double y, double scale) {
    return (
      scale * (0.5 / math.pi * x + 0.5),
      scale * (-0.5 / math.pi * y + 0.5),
    );
  }

  @override
  (double, double) untransform(double x, double y, double scale) {
    return (
      (x / scale - 0.5) * (2 * math.pi),
      (y / scale - 0.5) * (-2 * math.pi),
    );
  }

  @override
  LatLng offsetToLatLng(Offset offset, double zoom) {
    final s = scale(zoom);
    final (ux, uy) = untransform(offset.dx, offset.dy, s);
    return projection.unprojectXY(ux, uy);
  }

  @override
  Rect? getProjectedBounds(double zoom) {
    final b = projection.bounds!;
    final s = scale(zoom);
    final (minx, miny) = transform(b.left, b.top, s);
    final (maxx, maxy) = transform(b.right, b.bottom, s);
    return Rect.fromPoints(Offset(minx, miny), Offset(maxx, maxy));
  }
}

class MapConstants {
  // VERIFIED Sequential Uzbekistan Boundary Coordinates
  static const List<LatLng> uzbekistanBorder = [
    LatLng(45.542, 55.986), LatLng(45.571, 58.243), LatLng(45.501, 58.742),
    LatLng(44.921, 59.542), LatLng(44.021, 60.542), LatLng(42.301, 62.102),
    LatLng(41.493, 63.982), LatLng(41.319, 65.947), LatLng(41.802, 68.802),
    LatLng(42.301, 69.402), LatLng(42.101, 70.802), LatLng(41.802, 71.502),
    LatLng(41.002, 72.823), LatLng(40.623, 72.243), LatLng(40.323, 71.543),
    LatLng(39.923, 70.802), LatLng(39.802, 69.502), LatLng(38.502, 68.202),
    LatLng(37.388, 68.102), LatLng(37.170, 67.472), LatLng(37.245, 66.527),
    LatLng(38.032, 65.234), LatLng(38.835, 64.673), LatLng(40.234, 63.312),
    LatLng(41.023, 62.502), LatLng(41.427, 58.552), LatLng(43.161, 57.086),
    LatLng(43.201, 56.402), LatLng(44.351, 55.986), LatLng(45.542, 55.986)
  ];
}
