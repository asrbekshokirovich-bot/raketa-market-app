import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class YandexService {
  static const String apiTilesKey = '3f5ebf50-f9cb-4f84-a8a8-36cbf898935f';
  static const String geocoderApiKey = '8f570068-9634-477c-a942-f826bd633620';

  static Future<Map<String, dynamic>?> reverseGeocode(LatLng coords) async {
    try {
      final url = Uri.parse(
        'https://geocode-maps.yandex.ru/1.x/?apikey=$geocoderApiKey&format=json&geocode=${coords.longitude},${coords.latitude}&lang=uz_UZ&results=1',
      );
      
      print('=== Yandex API Request: $url ===');
      final response = await http.get(url);
      print('=== Yandex API Status: ${response.statusCode} ===');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Deep nested null checking
        final responseData = data['response'];
        if (responseData != null) {
          final geoObjectCollection = responseData['GeoObjectCollection'];
          if (geoObjectCollection != null) {
            final featureMember = geoObjectCollection['featureMember'];
            if (featureMember is List && featureMember.isNotEmpty) {
              final geoObject = featureMember[0]['GeoObject'];
              if (geoObject != null) {
                final metaDataProperty = geoObject['metaDataProperty'];
                if (metaDataProperty != null) {
                  final geocoderMetaData = metaDataProperty['GeocoderMetaData'];
                  if (geocoderMetaData != null) {
                    final address = geocoderMetaData['Address'];
                    if (address != null) {
                      final components = address['Component'] ?? address['Components'];
                      
                      Map<String, String> result = {
                        'display_name': address['formatted']?.toString() ?? '',
                      };

                      if (components is List) {
                        for (var comp in components) {
                          final kind = comp['kind']?.toString();
                          final name = comp['name']?.toString();
                          if (name == null) continue;

                          // Broad mapping for better coverage
                          if (kind == 'province') result['province'] = name;
                          if (kind == 'area' || kind == 'district') result['area'] = name;
                          if (kind == 'locality') result['locality'] = name;
                          if (kind == 'street') result['street'] = name;
                          if (kind == 'house') result['house'] = name;
                        }
                      }
                      
                      // Secondary check: if locality is empty but we have an area, use area as locality
                      if ((result['locality'] == null || result['locality']!.isEmpty) && result['area'] != null) {
                        result['locality'] = result['area'] ?? '';
                      }
                      
                      print('=== Yandex Parsed Details: $result ===');
                      return result;
                    }
                  }
                }
              }
            } else {
              print('Yandex: No features found at this location.');
            }
          }
        }
      } else {
        print('Yandex API Failed with body: ${response.body}');
      }
    } catch (e) {
      print('Yandex Geocoding Exception: $e');
    }

    // FALLBACK TO NOMINATIM
    print('!!! Falling back to Nominatim !!!');
    return await _fallbackNominatim(coords);
  }

  static Future<Map<String, dynamic>?> _fallbackNominatim(LatLng coords) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18&addressdetails=1&accept-language=uz');
      final response = await http.get(url, headers: {'User-Agent': 'com.abulfayiz.supermarket'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};
        
        final result = {
          'province': (address['state'] ?? address['region'] ?? address['province'] ?? '').toString(),
          'area': (address['city'] ?? address['town'] ?? address['village'] ?? '').toString(),
          'district': (address['city_district'] ?? address['suburb'] ?? address['neighbourhood'] ?? '').toString(),
          'street': (address['road'] ?? address['pedestrian'] ?? address['street'] ?? '').toString(),
          'house': (address['house_number'] ?? '').toString(),
          'display_name': (data['display_name'] ?? '').toString(),
        };
        print('=== Nominatim Fallback Success: ${result['display_name']} ===');
        return result;
      }
    } catch (e) {
      print('Nominatim Fallback Error: $e');
    }
    return null;
  }
}
