import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AddressItem {
  final String id;
  final String userId;
  final String name;
  final String region;
  final String district;
  final String street;
  final String? house;
  final bool isDefault;
  final double? lat;
  final double? lng;

  AddressItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.region,
    required this.district,
    required this.street,
    this.house,
    required this.isDefault,
    this.lat,
    this.lng,
  });

  factory AddressItem.fromMap(Map<String, dynamic> map) {
    return AddressItem(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      region: map['region'],
      district: map['district'],
      street: map['street'],
      house: map['house'],
      isDefault: map['is_default'] ?? false,
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] != null ? (map['lng'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'name': name,
      'region': region,
      'district': district,
      'street': street,
      'house': house,
      'is_default': isDefault,
      'lat': lat,
      'lng': lng,
    };
  }

  String get fullAddress {
    return "$region, $district, $street${house != null && house!.isNotEmpty ? ", $house" : ""}";
  }

  String get multiLineAddress {
    List<String> parts = [];
    if (region.isNotEmpty) parts.add(region);
    if (district.isNotEmpty) parts.add(district);
    if (street.isNotEmpty) parts.add(street);
    if (house != null && house!.isNotEmpty) parts.add(house!);
    return parts.join("\n");
  }
}

class AddressProvider with ChangeNotifier {
  List<AddressItem> _addresses = [];
  bool _isLoading = false;
  String? _userId;

  List<AddressItem> get addresses => _addresses;
  bool get isLoading => _isLoading;
  AddressItem? get defaultAddress => _addresses.firstWhere((a) => a.isDefault, orElse: () => _addresses.isNotEmpty ? _addresses.first : AddressItem(id: '', userId: '', name: '', region: '', district: '', street: '', isDefault: false));
  
  void updateUserId(String? userId) {
    if (_userId != userId) {
      _userId = userId;
      if (userId != null) {
        loadAddresses();
      } else {
        _addresses = [];
        notifyListeners();
      }
    }
  }

  Future<void> loadAddresses() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await SupabaseService.getUserAddresses(_userId!);
      _addresses = data.map((e) => AddressItem.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error loading addresses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addAddress(AddressItem address) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await SupabaseService.saveUserAddress(address.toMap());
      if (success) {
        await loadAddresses();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('AddressProvider Add Error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAddress(String addressId) async {
    final success = await SupabaseService.deleteUserAddress(addressId);
    if (success) {
      _addresses.removeWhere((a) => a.id == addressId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> setDefaultAddress(String addressId) async {
    if (_userId == null) return;
    await SupabaseService.setDefaultAddress(_userId!, addressId);
    await loadAddresses();
  }
}
