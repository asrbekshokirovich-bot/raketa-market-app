import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/top_toast.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/yandex_service.dart';
import '../utils/map_constants.dart';

class AddEditAddressScreen extends StatefulWidget {
  final AddressItem? address;

  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _districtController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isDefault = false;
  bool _isSaving = false;

  final MapController _mapController = MapController();
  LatLng _pickedLocation = const LatLng(37.2242, 67.2783);
  bool _isMapLoading = false;
  bool _isGeocoding = false;
  String _selectedRegion = "Surxondaryo viloyati";

  final List<String> _uzbekistanRegions = [
    "Andijon viloyati", "Buxoro viloyati", "Farg'ona viloyati", "Jizzax viloyati",
    "Namangan viloyati", "Navoiy viloyati", "Qashqadaryo viloyati", "Qoraqalpog'iston Respublikasi",
    "Samarqand viloyati", "Sirdaryo viloyati", "Surxondaryo viloyati", "Toshkent viloyati",
    "Toshkent shahri", "Xorazm viloyati",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _nameController.text = widget.address!.name;
      _districtController.text = widget.address!.district;
      _streetController.text = widget.address!.street;
      _houseController.text = widget.address!.house ?? '';
      _isDefault = widget.address!.isDefault;
      if (widget.address!.lat != null && widget.address!.lng != null) {
        _pickedLocation = LatLng(widget.address!.lat!, widget.address!.lng!);
      }
      _selectedRegion = widget.address!.region;
    } else {
      _pickedLocation = _getRegionCenter(_selectedRegion);
    }
  }

  Future<void> _fetchAddressInfo(LatLng coords, LocalizationProvider l10n) async {
    if (mounted) {
      setState(() {
        _isGeocoding = true;
        _districtController.text = "";
        _streetController.text = "";
        _houseController.text = "";
      });
    }

    try {
      final yandexData = await YandexService.reverseGeocode(coords);
      
      if (yandexData != null) {
        final province = yandexData['province'] ?? '';
        bool isCorrectRegion = false;
        final normalizedProvince = province.toString().toLowerCase();
        final normalizedSelected = _selectedRegion.toLowerCase().replaceAll(' viloyati', '').replaceAll(' shahri', '');
        
        if (normalizedProvince.contains(normalizedSelected) || normalizedSelected.contains(normalizedProvince) || province.isEmpty) {
          isCorrectRegion = true;
        }

        if (!isCorrectRegion) {
          if (mounted) {
            TopToast.show(context, "${l10n.translate('select_within')} $_selectedRegion", color: Colors.orange);
            setState(() => _isGeocoding = false);
          }
          return;
        }

        final district = yandexData['area'] ?? yandexData['district'] ?? yandexData['locality'] ?? '';
        final street = yandexData['street'] ?? '';
        final house = yandexData['house'] ?? '';

        if (mounted) {
          setState(() {
            _districtController.text = district;
            _streetController.text = street;
            _houseController.text = house;
            _isGeocoding = false;
          });
        }
      } else {
        if (mounted) setState(() => _isGeocoding = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isGeocoding = false);
    } finally {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  Future<void> _getCurrentLocation(LocalizationProvider l10n) async {
    setState(() => _isMapLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) TopToast.show(context, "GPS o'chirilgan", color: Colors.orange);
        setState(() => _isMapLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) TopToast.show(context, "Joylashuvga ruxsat berilmadi", color: Colors.redAccent);
          setState(() => _isMapLoading = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      final coords = LatLng(position.latitude, position.longitude);
      setState(() => _pickedLocation = coords);
      _mapController.move(coords, 16.0);
      _fetchAddressInfo(coords, l10n);
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.read<LocalizationProvider>();
    final addressProvider = context.read<AddressProvider>();
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(widget.address == null ? l10n.translate('add_new_address') : l10n.translate('malumot'), style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('pick_map'), style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[500])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black87, width: 1.2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRegion,
                  isExpanded: true,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRegion = val);
                      final center = _getRegionCenter(val);
                      _mapController.move(center, 12.0);
                      _pickedLocation = center;
                      _fetchAddressInfo(center, l10n);
                    }
                  },
                  items: _uzbekistanRegions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 220,
                decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        crs: const CrsYandex(),
                        initialCenter: _pickedLocation,
                        initialZoom: 18.5,
                        minZoom: 13.0,
                        maxZoom: 20.0,
                        onTap: (pos, point) {
                          setState(() => _pickedLocation = point);
                          _fetchAddressInfo(point, l10n);
                        },
                      ),
                      children: [
                        TileLayer(
                          key: const ValueKey('yandex_map_layer'),
                          urlTemplate: 'https://core-renderer-tiles.maps.yandex.net/tiles?l=map&x={x}&y={y}&z={z}&lang=ru_RU',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pickedLocation,
                              width: 60,
                              height: 60,
                              child: const Icon(Icons.location_on, color: Color(0xFFFF7A00), size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_isMapLoading) const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00))),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton.small(
                        onPressed: () => _getCurrentLocation(l10n),
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.my_location, color: Color(0xFFFF7A00)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    "${l10n.translate('coordinates') ?? 'Koordinatalar'}: ${_pickedLocation.latitude.toStringAsFixed(6)}, ${_pickedLocation.longitude.toStringAsFixed(6)}",
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(_districtController, l10n.translate('district_label'), Icons.location_city, isDark, isLoading: _isGeocoding),
            _buildTextField(_streetController, l10n.translate('street_label'), Icons.signpost, isDark, isLoading: _isGeocoding),
            _buildTextField(_houseController, l10n.translate('house_label'), Icons.home, isDark, isLoading: _isGeocoding),
            _buildTextField(_nameController, l10n.translate('address_title_label'), Icons.label, isDark),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.translate('set_as_default'), style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
              value: _isDefault,
              activeColor: const Color(0xFFFF7A00),
              onChanged: (val) => setState(() => _isDefault = val),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A00), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _isSaving ? null : () async {
                  if (_nameController.text.isEmpty || _districtController.text.isEmpty || _streetController.text.isEmpty) {
                    TopToast.show(context, l10n.translate('fill_all'), color: Colors.redAccent);
                    return;
                  }
                  setState(() => _isSaving = true);
                  final userId = authProvider.userProfile?['id']?.toString();
                  if (userId != null) {
                    final item = AddressItem(
                      id: widget.address?.id ?? '',
                      userId: userId,
                      name: _nameController.text,
                      region: _selectedRegion,
                      district: _districtController.text,
                      street: _streetController.text,
                      house: _houseController.text,
                      isDefault: _isDefault,
                      lat: _pickedLocation.latitude,
                      lng: _pickedLocation.longitude,
                    );
                    if (await addressProvider.addAddress(item)) {
                      if (_isDefault && widget.address?.id != null) await addressProvider.setDefaultAddress(widget.address!.id);
                      if (mounted) {
                        TopToast.show(context, l10n.translate('address_saved'), color: Colors.green);
                        Navigator.pop(context);
                      }
                    }
                  }
                  setState(() => _isSaving = false);
                },
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(l10n.translate('save_address'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String? label, IconData icon, bool isDark, {bool isLoading = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white24 : Colors.black87, width: 1.2)),
      child: TextField(
        controller: controller,
        readOnly: isLoading,
        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 13),
          hintText: isLoading ? "Yuklanmoqda..." : label,
          prefixIcon: isLoading ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A00)))) : Icon(icon, color: isDark ? Colors.white70 : Colors.black87),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  LatLng _getRegionCenter(String region) {
    switch (region) {
      case "Toshkent shahri": return const LatLng(41.2995, 69.2401);
      case "Toshkent viloyati": return const LatLng(41.2212, 69.7423);
      case "Andijon viloyati": return const LatLng(40.7833, 72.3333);
      case "Buxoro viloyati": return const LatLng(39.7747, 64.4286);
      case "Farg'ona viloyati": return const LatLng(40.3833, 71.7833);
      case "Jizzax viloyati": return const LatLng(40.1167, 67.8333);
      case "Namangan viloyati": return const LatLng(41.0011, 71.6683);
      case "Navoiy viloyati": return const LatLng(40.1031, 65.3739);
      case "Qashqadaryo viloyati": return const LatLng(38.8667, 65.8);
      case "Samarqand viloyati": return const LatLng(39.6542, 66.9597);
      case "Sirdaryo viloyati": return const LatLng(40.4833, 68.7833);
      case "Surxondaryo viloyati": return const LatLng(37.2242, 67.2783);
      case "Xorazm viloyati": return const LatLng(41.55, 60.6333);
      case "Qoraqalpog'iston Respublikasi": return const LatLng(43.0, 59.0);
      default: return const LatLng(41.2995, 69.2401);
    }
  }
}
