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
import '../services/supabase_service.dart';
import '../utils/map_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String _selectedRegion = ""; // Bo'sh — viloyat tanlang
  List<String> _activeRegions = [];
  bool _isLoadingRegions = true;
  RealtimeChannel? _regionChannel;

  bool get _regionSelected => _selectedRegion.isNotEmpty;

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
    }
    // Yangi manzil uchun viloyat tanlanmagan — xarita Surxondaryoda turadi lekin bloklangan
    _fetchActiveRegions();
    _subscribeToRegionChanges();
  }

  void _subscribeToRegionChanges() {
    _regionChannel = SupabaseService.client
        .channel('active_regions_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'app_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'key',
            value: 'active_regions',
          ),
          callback: (payload) {
            _fetchActiveRegions();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _regionChannel?.unsubscribe();
    _districtController.dispose();
    _streetController.dispose();
    _houseController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  final Map<String, String> _regionMapping = {
    "Toshkent shahri": "tashkent_city",
    "Toshkent viloyati": "tashkent_v",
    "Andijon viloyati": "andijan",
    "Buxoro viloyati": "bukhara",
    "Farg'ona viloyati": "fergana",
    "Jizzax viloyati": "jizzakh",
    "Namangan viloyati": "namangan",
    "Navoiy viloyati": "navoiy",
    "Qashqadaryo viloyati": "qashqadaryo",
    "Samarqand viloyati": "samarqand",
    "Sirdaryo viloyati": "sirdaryo",
    "Surxondaryo viloyati": "surxondaryo",
    "Xorazm viloyati": "xorazm",
    "Qoraqalpog'iston Respublikasi": "karakalpakstan",
  };

  Future<void> _fetchActiveRegions() async {
    setState(() => _isLoadingRegions = true);
    try {
      final regions = await SupabaseService.getActiveRegions();
      if (mounted) {
        setState(() {
          _activeRegions = regions;
          _isLoadingRegions = false;
          // Yangi manzil uchun viloyat avtomatik tanlanmaydi — foydalanuvchi o'zi tanlashi kerak
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRegions = false);
    }
  }

  bool _isRegionActive(String region) {
    if (_isLoadingRegions) return false;
    if (_activeRegions.isEmpty) return false;
    
    final slug = _regionMapping[region];
    if (slug == null) return false;
    
    final isActive = _activeRegions.contains(slug);
    debugPrint('AddEditAddressScreen: $region (slug: $slug) isActive: $isActive, list: $_activeRegions');
    return isActive;
  }

  Future<void> _fetchAddressInfo(LatLng coords, LocalizationProvider l10n, {bool updateRegion = true}) async {
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
        final prov = yandexData['province']?.toString().toLowerCase() ?? '';
        String? newRegion;

        if (prov.isNotEmpty) {
          final normProv = prov.replaceAll(RegExp(r"[^a-zа-я0-9]"), "");
          for (var region in _regionMapping.keys) {
            final baseName = region.split(' ').first.toLowerCase();
            final normBase = baseName.replaceAll(RegExp(r"[^a-zа-я0-9]"), "");
            
            if (normProv.contains(normBase)) {
              if (normBase == 'toshkent') {
                if (prov.contains('shahri') || prov.contains('gorod') || prov.contains('city')) {
                  newRegion = "Toshkent shahri";
                } else {
                  newRegion = "Toshkent viloyati";
                }
              } else {
                newRegion = region;
              }
              break;
            }
          }
        }

        if (updateRegion && newRegion != null && _selectedRegion != newRegion) {
           setState(() {
             _selectedRegion = newRegion!;
           });
           if (!_isRegionActive(newRegion)) {
             _showNotActiveDialog(Theme.of(context).brightness == Brightness.dark, l10n);
           }
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
        if (mounted) TopToast.show(context, l10n.translate('gps_disabled'), color: Colors.orange);
        setState(() => _isMapLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) TopToast.show(context, l10n.translate('location_permission_denied'), color: Colors.redAccent);
          setState(() => _isMapLoading = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      final coords = LatLng(position.latitude, position.longitude);
      setState(() => _pickedLocation = coords);
      _mapController.move(coords, 18.5);
      _fetchAddressInfo(coords, l10n);
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label, 
    String? hint,
    required IconData prefixIcon,
    required TextEditingController controller, 
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    required bool isDark,
    bool isLoading = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: isLoading,
        keyboardType: type,
        maxLines: maxLines,
        style: GoogleFonts.montserrat(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: isLoading ? "Yuklanmoqda..." : hint,
          labelStyle: GoogleFonts.montserrat(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: GoogleFonts.montserrat(
            color: Colors.grey[400],
            fontSize: 13,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A00)))
              : Icon(
                  prefixIcon,
                  color: Colors.grey[500],
                  size: 24,
                ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!, 
              width: 1.5
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  void _showRegionMenu(bool isDark, LocalizationProvider l10n) {
    final regions = [
      "Toshkent shahri", "Toshkent viloyati", "Andijon viloyati", "Buxoro viloyati", 
      "Farg'ona viloyati", "Jizzax viloyati", "Namangan viloyati", "Navoiy viloyati", 
      "Qashqadaryo viloyati", "Samarqand viloyati", "Sirdaryo viloyati", 
      "Surxondaryo viloyati", "Xorazm viloyati", "Qoraqalpog'iston Respublikasi"
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.translate('region_select_title'),
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    // Update regions if they change externally (though setState in parent usually handles this if called before modal)
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: regions.length,
                      itemBuilder: (context, index) {
                        final region = regions[index];
                        final isActive = _isRegionActive(region);
                        final isSelected = _selectedRegion == region;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFFFF7A00).withOpacity(0.1) 
                                : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9FAFB)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? const Color(0xFFFF7A00) 
                                  : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              if (isActive) {
                                setState(() {
                                  _selectedRegion = region;
                                  _pickedLocation = _getRegionCenter(region);
                                });
                                _mapController.move(_pickedLocation, 12);
                                _fetchAddressInfo(_pickedLocation, l10n, updateRegion: false);
                                Navigator.pop(context);
                              } else {
                                Navigator.pop(context);
                                _showNotActiveDialog(isDark, l10n);
                              }
                            },
                            leading: Icon(
                              Icons.map_rounded,
                              color: isSelected ? const Color(0xFFFF7A00) : Colors.grey[500],
                            ),
                            title: Text(
                              region,
                              style: GoogleFonts.montserrat(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            trailing: isActive
                                ? (isSelected ? const Icon(Icons.check_circle, color: Color(0xFFFF7A00)) : null)
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      l10n.translate('coming_soon'),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotActiveDialog(bool isDark, LocalizationProvider l10n) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.82,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Illustration circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF7A00).withOpacity(0.15),
                          const Color(0xFFFF9F45).withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.location_off_rounded, color: Color(0xFFFF7A00), size: 36),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Title
                  Text(
                    l10n.translate('sorry'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    l10n.translate('no_service'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.translate('understand'),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegionSelector(bool isDark, LocalizationProvider l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
            child: Text(
              l10n.translate('region_label'),
              style: GoogleFonts.montserrat(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: () => _showRegionMenu(isDark, l10n),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _regionSelected ? Icons.map_rounded : Icons.map_outlined,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _regionSelected ? _selectedRegion : l10n.translate('select_region_hint'),
                      style: GoogleFonts.montserrat(
                        color: _regionSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.read<LocalizationProvider>();
    final addressProvider = context.read<AddressProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          widget.address == null ? l10n.translate('add_new_address') : l10n.translate('malumot'),
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  _buildRegionSelector(isDark, l10n),
                  _buildCard([
                    _buildSectionTitle(l10n.translate('your_address'), isDark),
                    Container(
                      height: 190,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFF7A00).withOpacity(0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          AbsorbPointer(
                            absorbing: !_regionSelected, // Viloyat tanlanmaguncha xarita bloklangan
                            child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              crs: const CrsYandex(),
                              initialCenter: _pickedLocation,
                              initialZoom: 18.5,
                              onTap: !_regionSelected ? null : (pos, point) {
                                setState(() => _pickedLocation = point);
                                _fetchAddressInfo(point, l10n);
                              },
                            ),
                            children: [
                              TileLayer(
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
                          ),
                          // Viloyat tanlanmagan bo'lsa overlay
                          if (!_regionSelected)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.map_rounded, color: Colors.white, size: 32),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.translate('add_address_prompt'),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (_isMapLoading)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.1),
                                child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00))),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              elevation: 2,
                              child: InkWell(
                                onTap: () => _getCurrentLocation(l10n),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.my_location_rounded, color: Color(0xFFFF7A00), size: 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Coordinate Box (Compact)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location_rounded, color: const Color(0xFF007AFF).withOpacity(0.7), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "${_pickedLocation.latitude.toStringAsFixed(6)}, ${_pickedLocation.longitude.toStringAsFixed(6)}",
                            style: GoogleFonts.montserrat(
                              fontSize: 12, 
                              fontWeight: FontWeight.w700, 
                              color: isDark ? Colors.grey[400] : Colors.grey[700]
                            ),
                          ),
                        ],
                      ),
                    ),
                  ], isDark),

                  _buildCard([
                    _buildSectionTitle(l10n.translate('address_details'), isDark),
                    _buildTextField(label: l10n.translate('name_label'), prefixIcon: Icons.label_important_outline, controller: _nameController, isDark: isDark),
                    _buildTextField(label: l10n.translate('district_label'), prefixIcon: Icons.location_city_rounded, controller: _districtController, isDark: isDark, isLoading: _isGeocoding),
                    _buildTextField(label: l10n.translate('street_label'), prefixIcon: Icons.add_road_rounded, controller: _streetController, isDark: isDark, isLoading: _isGeocoding),
                    _buildTextField(label: l10n.translate('house_label'), prefixIcon: Icons.home_work_rounded, controller: _houseController, isDark: isDark, isLoading: _isGeocoding),
                    
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.translate('set_as_default'), style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      value: _isDefault,
                      activeThumbColor: const Color(0xFFFF7A00),
                      onChanged: (val) => setState(() => _isDefault = val),
                    ),
                  ], isDark),
                ],
              ),
            ),
            // Bottom Panel
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _regionSelected && !_isRegionActive(_selectedRegion) ? Colors.redAccent : const Color(0xFFFF7A00),
                    disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: (_isSaving || !_regionSelected || !_isRegionActive(_selectedRegion)) ? null : () async {
                     if (!_regionSelected) {
                        TopToast.show(context, l10n.translate('add_address_prompt'), color: Colors.orange);
                        return;
                      }
                     if (_nameController.text.isEmpty || _districtController.text.isEmpty || _streetController.text.isEmpty) {
                        TopToast.show(context, l10n.translate('fill_all'), color: Colors.redAccent);
                        return;
                      }
                      
                      if (!_isRegionActive(_selectedRegion)) {
                        TopToast.show(context, l10n.translate('region_not_active'), color: Colors.orange);
                        return;
                      }

                      setState(() => _isSaving = true);
                      
                      final authProvider = context.read<AuthProvider>();
                      final userId = authProvider.userProfile?['id']?.toString();
                      
                      if (userId != null) {
                        final address = AddressItem(
                          id: widget.address?.id ?? '',
                          userId: userId,
                          name: _nameController.text,
                          region: _selectedRegion,
                          district: _districtController.text,
                          street: _streetController.text,
                          house: _houseController.text,
                          lat: _pickedLocation.latitude,
                          lng: _pickedLocation.longitude,
                          isDefault: _isDefault,
                        );

                        await addressProvider.addAddress(address);

                        if (mounted) {
                          TopToast.show(context, l10n.translate('address_saved'), color: Colors.green);
                          Navigator.pop(context);
                        }
                      }
                      setState(() => _isSaving = false);
                  },
                  child: _isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        l10n.translate('save_address'),
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ),
          ],
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
      case "Qashqadaryo viloyati": return const LatLng(38.841605, 65.789979);
      case "Samarqand viloyati": return const LatLng(39.6542, 66.9597);
      case "Sirdaryo viloyati": return const LatLng(40.4833, 68.7833);
      case "Surxondaryo viloyati": return const LatLng(37.2242, 67.2783);
      case "Xorazm viloyati": return const LatLng(41.55, 60.6333);
      case "Qoraqalpog'iston Respublikasi": return const LatLng(43.0, 59.0);
      default: return const LatLng(41.2995, 69.2401);
    }
  }
}
