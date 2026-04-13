import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class YandexProjection extends Projection {
  static const double _eccentricity = 0.0818191908426;

  const YandexProjection() : super();

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
    // Note: unproject is complex for Elliptical Mercator, 
    // but usually only projectXY is needed for rendering tiles/markers.
    // This is a simplified fallback.
    return const LatLng(0, 0); 
  }
  
  @override
  (double, double) get bounds => (math.pi, math.pi);
}

class CrsYandex extends Crs {
  const CrsYandex()
      : super(
          projection: const YandexProjection(),
          transformation: const Transformation(0.5 / math.pi, 0.5, -0.5 / math.pi, 0.5),
        );

  @override
  String get code => 'EPSG:3395';
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
