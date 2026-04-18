import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../widgets/top_notification.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/localization_provider.dart';
import '../services/supabase_service.dart';
import '../providers/address_provider.dart';
import '../services/yandex_service.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/map_constants.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final MapController _mapController = MapController();
  final LatLng _storeLocation = const LatLng(41.332306, 69.282835);
  
  Timer? _debounce;
  String _geocodedAddress = '';
  String _coordinateString = '';
  LatLng _currentMapPosition = const LatLng(41.2995, 69.2401);
  bool _isMapLoading = false;

  // --- Region Selection (CRM boshqaruvi) ---
  String _selectedRegion = '';
  List<String> _activeRegions = [];
  bool _isLoadingRegions = true;
  RealtimeChannel? _regionChannel;
  bool get _regionSelected => _selectedRegion.isNotEmpty;

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

  String _fC(double amount) {
    final formatter = NumberFormat("#,###", "en_US");
    return formatter.format(amount).replaceAll(',', ' ');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_geocodedAddress.isEmpty) {
      _geocodedAddress = context.read<LocalizationProvider>().translate('searching_address');
    }
    if (_coordinateString.isEmpty) {
      _coordinateString = '41.2995, 69.2401';
    }
  }

  Future<void> _fetchAddressInfo(LatLng coords, {bool updateRegion = true}) async {
    try {
      final data = await YandexService.reverseGeocode(coords);
      if (data != null && mounted) {
        final prov = data['province']?.toString().toLowerCase() ?? '';
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
             _showCheckoutNotActiveDialog(Theme.of(context).brightness == Brightness.dark, context.read<LocalizationProvider>());
           }
        }

        setState(() {
          _geocodedAddress = data['display_name'] ?? context.read<LocalizationProvider>().translate('unknown_area');
          _coordinateString = '${coords.latitude.toStringAsFixed(6)}, ${coords.longitude.toStringAsFixed(6)}';
        });
      } else {
        if (mounted) setState(() => _geocodedAddress = context.read<LocalizationProvider>().translate('cannot_determine_address'));
      }
    } catch (e) {
      if (mounted) setState(() => _geocodedAddress = context.read<LocalizationProvider>().translate('connection_error'));
    }
  }

  Future<void> _getCurrentLocation() async {
    final l10n = context.read<LocalizationProvider>();
    setState(() => _isMapLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) TopNotification.show(context, l10n.translate('gps_disabled'), isError: true);
        setState(() => _isMapLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) TopNotification.show(context, l10n.translate('location_permission_denied'), isError: true);
          setState(() => _isMapLoading = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      final coords = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentMapPosition = coords;
        _isMapLoading = false;
        _coordinateString = '${coords.latitude.toStringAsFixed(6)}, ${coords.longitude.toStringAsFixed(6)}';
      });
      _mapController.move(coords, 18.5);
      _fetchAddressInfo(coords);
    } catch (e) {
      if (mounted) TopNotification.show(context, l10n.translate('unable_to_determine_location'), isError: true);
      setState(() => _isMapLoading = false);
    }
  }

  String _deliveryMethod = 'delivery';
  String _paymentMethod = 'cash';

  final TextEditingController _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _promoController = TextEditingController();
  double _discountAmount = 0;
  bool _isPromoApplied = false;
  String? _appliedPromoId;
  String? _promoTarget;
  String? _promoType;
  double? _promoValue;
  bool _isCheckingPromo = false;

  AddressItem? _selectedSavedAddress;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Har doim eng so'nggi dastavka narxlarini olish uchun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().fetchDeliveryConfig();
    });
    _loadCustomerInfo();
    _fetchActiveRegions();
    _subscribeToRegionChanges();
  }

  Future<void> _fetchActiveRegions() async {
    setState(() => _isLoadingRegions = true);
    try {
      final regions = await SupabaseService.getActiveRegions();
      if (mounted) {
        setState(() {
          _activeRegions = regions;
          _isLoadingRegions = false;
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
    return _activeRegions.contains(slug);
  }

  void _subscribeToRegionChanges() {
    _regionChannel = SupabaseService.client
        .channel('checkout_regions_changes')
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

  void _showCheckoutRegionMenu(bool isDark, LocalizationProvider l10n) {
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
      builder: (ctx) {
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
                width: 40, height: 4,
                decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.translate('region_select_title'), style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    final isActive = _isRegionActive(region);
                    final isSelected = _selectedRegion == region;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF7A00).withOpacity(0.1) : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9FAFB)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? const Color(0xFFFF7A00) : (isDark ? Colors.grey[800]! : Colors.grey[200]!), width: 1.5),
                      ),
                      child: ListTile(
                        onTap: () {
                          if (isActive) {
                            setState(() {
                              _selectedRegion = region;
                              _currentMapPosition = _getRegionCenter(region);
                              _selectedSavedAddress = null;
                              _geocodedAddress = l10n.translate('searching_address');
                              _coordinateString = '${_currentMapPosition.latitude.toStringAsFixed(6)}, ${_currentMapPosition.longitude.toStringAsFixed(6)}';
                            });
                            _mapController.move(_currentMapPosition, 12);
                            _fetchAddressInfo(_currentMapPosition, updateRegion: false);
                            Navigator.pop(ctx);
                          } else {
                            Navigator.pop(ctx);
                            _showCheckoutNotActiveDialog(isDark, l10n);
                          }
                        },
                        leading: Icon(Icons.map_rounded, color: isSelected ? const Color(0xFFFF7A00) : Colors.grey[500]),
                        title: Text(region, style: GoogleFonts.montserrat(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                        trailing: isActive
                            ? (isSelected ? const Icon(Icons.check_circle, color: Color(0xFFFF7A00)) : null)
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(l10n.translate('coming_soon'), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCheckoutNotActiveDialog(bool isDark, LocalizationProvider l10n) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack), child: FadeTransition(opacity: anim1, child: child));
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFFFF7A00).withOpacity(0.15), const Color(0xFFFF9F45).withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Icon(Icons.location_off_rounded, color: Color(0xFFFF7A00), size: 36)),
                  ),
                  const SizedBox(height: 18),
                  Text(l10n.translate('sorry'), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  Text(l10n.translate('no_service'), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 14, height: 1.6, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A00), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      child: Text(l10n.translate('understand'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15)),
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

  Widget _buildCheckoutRegionSelector(bool isDark, LocalizationProvider l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showCheckoutRegionMenu(isDark, l10n),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _regionSelected && !_isRegionActive(_selectedRegion) 
              ? Colors.redAccent.withOpacity(0.05) 
              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _regionSelected && !_isRegionActive(_selectedRegion) 
                ? Colors.redAccent 
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!), 
              width: 1.5
            ),
          ),
          child: Row(
            children: [
              Icon(_regionSelected ? Icons.map_rounded : Icons.map_outlined, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _regionSelected ? _selectedRegion : l10n.translate('select_region_hint'),
                  style: GoogleFonts.montserrat(
                    color: _regionSelected ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.grey[400] : Colors.grey[600]),
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
    );
  }

  Future<void> _loadCustomerInfo() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoggedIn) {
      if (mounted) {
        setState(() {
          _nameController.text = auth.userProfile?['full_name'] ?? "";
          _phoneController.text = auth.userProfile?['phone'] ?? "";
        });
      }
    } else {
      final info = await SupabaseService.getCustomerInfo();
      if (mounted) {
        setState(() {
          if (info['name'] != null) _nameController.text = info['name']!;
          if (info['phone'] != null) _phoneController.text = info['phone']!;
        });
      }
    }
  }

  @override
  void dispose() {
    _regionChannel?.unsubscribe();
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 14,
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
    bool readOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: IgnorePointer(
        ignoring: readOnly,
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: type,
          maxLines: maxLines,
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
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
              child: Icon(
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
      ),
    );
  }

  Widget _buildCard(List<Widget> children, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }


  Widget _buildSelectableOption({
    required String title,
    required String emojiIcon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF7A00).withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7A00) : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFFF7A00).withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected ? [
                  BoxShadow(
                     color: const Color(0xFFFF7A00).withOpacity(0.2),
                     blurRadius: 8,
                     offset: const Offset(0, 3),
                  )
                ] : [
                  BoxShadow(
                     color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                     blurRadius: 5,
                     offset: const Offset(0, 2),
                  )
                ]
              ),
              child: Text(
                emojiIcon,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFFF7A00), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedDivider(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashSpace = 3.0;
        final dashCount = (constraints.constrainWidth() / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[300]),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPromoItemRow(CartItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: item.imagePath.startsWith('http')
                  ? CachedNetworkImage(imageUrl: item.imagePath, fit: BoxFit.cover)
                  : Image.asset(item.imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.quantity} ${item.unit} x ${_fC(double.tryParse(item.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_fC((double.tryParse(item.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) * item.quantity)}',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
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
    final cart = context.watch<CartProvider>();
    final deliveryFee = _deliveryMethod == 'delivery' ? cart.calculateDeliveryFee(cart.totalAmount) : 0.0;
    // Hisob-kitob uchun maxsulotlarni ajratish
    final selectedItems = cart.items.values.where((i) => i.isSelected).toList();
    final discountedBasketItems = selectedItems.where((i) => i.oldPrice != null).toList();
    final nonDiscountedBasketItems = selectedItems.where((i) => i.oldPrice == null).toList();

    double discountedTotalValue = 0;
    for (var i in discountedBasketItems) {
      discountedTotalValue += (double.tryParse(i.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) * i.quantity;
    }

    double nonDiscountedTotalValue = 0;
    for (var i in nonDiscountedBasketItems) {
      nonDiscountedTotalValue += (double.tryParse(i.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) * i.quantity;
    }

    final total = (cart.totalAmount + deliveryFee) - _discountAmount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          context.watch<LocalizationProvider>().translate('checkout'),
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Contact Info
                  _buildCard([
                    _buildSectionTitle(context.watch<LocalizationProvider>().translate('contact_info'), isDark),
                    _buildTextField(label: context.watch<LocalizationProvider>().translate('full_name'), prefixIcon: Icons.person_rounded, controller: _nameController, isDark: isDark, readOnly: true),
                    _buildTextField(label: context.watch<LocalizationProvider>().translate('phone_number'), prefixIcon: Icons.phone_rounded, controller: _phoneController, type: TextInputType.phone, isDark: isDark, readOnly: true),
                  ], isDark),

                  // Delivery Method
                  _buildCard([
                    _buildSectionTitle(context.watch<LocalizationProvider>().translate('receive_method'), isDark),
                    _buildSelectableOption(
                      title: context.watch<LocalizationProvider>().translate('delivery'),
                      emojiIcon: '🚚',
                      isSelected: _deliveryMethod == 'delivery',
                      onTap: () => setState(() => _deliveryMethod = 'delivery'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildSelectableOption(
                      title: context.watch<LocalizationProvider>().translate('pickup'),
                      emojiIcon: '🏬',
                      isSelected: _deliveryMethod == 'pickup',
                      onTap: () => setState(() => _deliveryMethod = 'pickup'),
                      isDark: isDark,
                    ),
                  ], isDark),

                  // Address Info (Conditional)
                  if (_deliveryMethod == 'delivery') ...[
                    Consumer<AddressProvider>(
                      builder: (context, addressProvider, child) {
                        if (addressProvider.addresses.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(l10n.translate('my_address'), isDark),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: addressProvider.addresses.length,
                                itemBuilder: (context, index) {
                                  final addr = addressProvider.addresses[index];
                                  final isSelected = _selectedSavedAddress?.id == addr.id;
                                  return GestureDetector(
                                    onTap: () {
                                      if (addr.region.isNotEmpty && !_isRegionActive(addr.region)) {
                                        _showCheckoutNotActiveDialog(Theme.of(context).brightness == Brightness.dark, l10n);
                                        return;
                                      }

                                      setState(() {
                                        _selectedSavedAddress = addr;
                                        _geocodedAddress = addr.fullAddress;
                                        // Avtomatik viloyatni tanlash (agar mavjud bo'lsa)
                                        if (addr.region.isNotEmpty) {
                                          _selectedRegion = addr.region;
                                        }
                                        if (addr.lat != null && addr.lng != null) {
                                          _currentMapPosition = LatLng(addr.lat!, addr.lng!);
                                          _mapController.move(_currentMapPosition, 18.5);
                                          _coordinateString = '${addr.lat!.toStringAsFixed(6)}, ${addr.lng!.toStringAsFixed(6)}';
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 160,
                                      margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFFF7A00).withOpacity(0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isSelected ? const Color(0xFFFF7A00) : (isDark ? Colors.grey[800]! : Colors.grey[200]!), width: 1.5),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(isSelected ? Icons.check_circle_rounded : Icons.location_on_rounded, size: 16, color: const Color(0xFFFF7A00)),
                                              const SizedBox(width: 6),
                                              Expanded(child: Text(addr.name, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(addr.fullAddress, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                    _buildCheckoutRegionSelector(isDark, l10n),
                    _buildCard([
                      _buildSectionTitle(context.watch<LocalizationProvider>().translate('your_address'), isDark),
                      Container(
                        height: 220,
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
                              absorbing: !_regionSelected,
                              child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                crs: const CrsYandex(),
                                initialCenter: _currentMapPosition,
                                initialZoom: 18.5,
                                onTap: !_regionSelected ? null : (tapPosition, point) {
                                  setState(() {
                                    _selectedSavedAddress = null;
                                    _currentMapPosition = point;
                                    _geocodedAddress = context.read<LocalizationProvider>().translate('searching_address');
                                    _coordinateString = '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
                                  });
                                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                                  _debounce = Timer(const Duration(milliseconds: 600), () {
                                    _fetchAddressInfo(point);
                                  });
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://core-renderer-tiles.maps.yandex.net/tiles?l=map&x={x}&y={y}&z={z}&lang=ru_RU',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _currentMapPosition,
                                      width: 60,
                                      height: 60,
                                      child: const Icon(Icons.location_on, color: Color(0xFFFF7A00), size: 40),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ),
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
                                        Text(l10n.translate('add_address_prompt'), style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
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
                                  onTap: _getCurrentLocation,
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
                      // New Geocoded Address Box
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF7A00).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _regionSelected && !_isRegionActive(_selectedRegion) 
                                  ? Colors.redAccent.withOpacity(0.1) 
                                  : const Color(0xFFFF7A00).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.location_on_rounded, 
                                color: _regionSelected && !_isRegionActive(_selectedRegion) ? Colors.redAccent : const Color(0xFFFF7A00), 
                                size: 24
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _geocodedAddress,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Coordinate Box
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF007AFF).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.my_location_rounded, color: Color(0xFF007AFF), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _coordinateString,
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ], isDark),

                    // Courier description separate part
                    _buildCard([
                      _buildSectionTitle(context.watch<LocalizationProvider>().translate('courier_desc'), isDark),
                      _buildTextField(
                        label: context.watch<LocalizationProvider>().translate('courier_desc'),
                        hint: context.watch<LocalizationProvider>().translate('courier_desc_hint'),
                        prefixIcon: Icons.door_front_door_rounded,
                        controller: _addressController,
                        isDark: isDark,
                      ),
                    ], isDark),
                  ],
                  // Pickup Store Address (Conditional)
                  if (_deliveryMethod == 'pickup')
                    _buildCard([
                      _buildSectionTitle(context.watch<LocalizationProvider>().translate('store_address'), isDark),
                       Container(
                        height: 160,
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
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                crs: const CrsYandex(),
                                initialCenter: _storeLocation,
                                initialZoom: 15.0,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://core-renderer-tiles.maps.yandex.net/tiles?l=map&x={x}&y={y}&z={z}&lang=ru_RU',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _storeLocation,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(Icons.location_on, color: Color(0xFFFF7A00), size: 40),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: isDark ? Colors.grey[800] : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                elevation: 2,
                                child: InkWell(
                                  onTap: () {
                                    _mapController.move(_storeLocation, 16.0);
                                  },
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF7A00).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Color(0xFFFF7A00), size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.watch<LocalizationProvider>().translate('raketa_main_branch'),
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.watch<LocalizationProvider>().translate('store_address_detail'),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.directions_rounded, color: Colors.white),
                          label: Text(
                            l10n.translate('get_directions'),
                            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A00),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ], isDark),

                  // Promo Logic - Consolidated into a single card
                  Consumer<CartProvider>(
                    builder: (context, cartProvider, child) {
                      final l10n = context.read<LocalizationProvider>();
                      final discounted = cartProvider.items.values.where((i) => i.isSelected && i.oldPrice != null).toList();
                      final nonDiscounted = cartProvider.items.values.where((i) => i.isSelected && i.oldPrice == null).toList();
                      
                      double discountedTotal = 0;
                      for (var i in discounted) {
                        discountedTotal += (double.tryParse(i.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) * i.quantity;
                      }
                      
                      double nonDiscountedTotal = 0;
                      for (var i in nonDiscounted) {
                        nonDiscountedTotal += (double.tryParse(i.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) * i.quantity;
                      }

                      return _buildCard([
                        Row(
                          children: [
                            const Icon(Icons.shopping_cart_outlined, color: Color(0xFFFF7A00), size: 24),
                            const SizedBox(width: 12),
                            Text(
                              l10n.translate('products_label'),
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (discounted.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                l10n.translate('discounted_products'),
                                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...discounted.map((item) => _buildPromoItemRow(item, isDark)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${l10n.translate('jami')}: ', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey)),
                                Text('${_fC(discountedTotal)} ${l10n.translate('som')}', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const Divider(),
                        ],

                        if (nonDiscounted.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, color: Color(0xFFFF7A00), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                l10n.translate('non_discounted_products'),
                                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFFF7A00)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...nonDiscounted.map((item) => _buildPromoItemRow(item, isDark)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${l10n.translate('jami')}: ', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey)),
                                Text('${_fC(nonDiscountedTotal)} ${l10n.translate('som')}', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),
                      ], isDark);
                    },
                  ),

                  // Dedicated Promo Code Card
                  Consumer<CartProvider>(
                    builder: (context, cartProvider, child) {
                      final l10n = context.read<LocalizationProvider>();
                      return _buildCard([
                        Row(
                          children: [
                            Text(
                              l10n.translate('promo_code'),
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                    title: Text(
                                      l10n.translate('promo_info_title'),
                                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.translate('promo_info_text_main'),
                                            style: GoogleFonts.montserrat(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.orange : const Color(0xFFFF9800)).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: (isDark ? Colors.orange : const Color(0xFFFF9800)).withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              l10n.translate('promo_info_text_important'),
                                              style: GoogleFonts.montserrat(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.orange[300] : const Color(0xFFE65100),
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          'OK',
                                          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFFFF7A00)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.info_outline,
                                size: 18,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Promo Information Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blue.withOpacity(0.08) : const Color(0xFFF0F7FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_rounded, color: isDark ? Colors.blue[300] : Colors.blue[600], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.translate('promo_eligibility_note'),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: isDark ? Colors.blue[100] : Colors.blue[900],
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _promoController,
                                enabled: !_isPromoApplied,
                                style: GoogleFonts.montserrat(
                                  color: isDark ? (_isPromoApplied ? Colors.grey : Colors.white) : (_isPromoApplied ? Colors.grey : Colors.black87),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.translate('enter_promo'),
                                  hintStyle: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 13),
                                  prefixIcon: const Icon(Icons.confirmation_num_rounded, color: Colors.grey, size: 20),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(20),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 48,
                              child: _isCheckingPromo 
                                ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A00))))
                                : ElevatedButton(
                                onPressed: _isPromoApplied ? null : () async {
                                  if (_promoController.text.isEmpty) return;
                                  
                                  setState(() => _isCheckingPromo = true);
                                  
                                  // Faqat chegirmasiz mahsulotlar yig'indisini hisoblash
                                  final nonDiscountedItems = cartProvider.items.values.where((i) => i.isSelected && i.oldPrice == null).toList();
                                  double nonDiscountedTotal = 0;
                                  for (var i in nonDiscountedItems) {
                                    nonDiscountedTotal += (double.tryParse(i.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) * i.quantity;
                                  }

                                  final deliveryFee = _deliveryMethod == 'delivery' ? cart.calculateDeliveryFee(cart.totalAmount) : 0.0;

                                  final result = await SupabaseService.validatePromoCode(
                                    code: _promoController.text.trim(),
                                    phone: _phoneController.text.trim(),
                                    subTotal: nonDiscountedTotal, // Faqat chegirmasizlar uchun
                                    deliveryFee: deliveryFee,
                                  );

                                  if (mounted) {
                                    setState(() => _isCheckingPromo = false);
                                    
                                    if (result['success'] == true) {
                                      setState(() {
                                        _discountAmount = (result['discount'] as num).toDouble();
                                        _isPromoApplied = true;
                                        _appliedPromoId = result['promo_id'];
                                        _promoTarget = result['target'];
                                        _promoType = result['type'];
                                        _promoValue = (result['value'] as num).toDouble();
                                      });
                                      TopNotification.show(context, l10n.translate('promo_applied'));
                                    } else {
                                      String msg = l10n.translate(result['message_key'] ?? 'wrong_promo');
                                      if (result['message_key'] == 'promo_min_amount_error') {
                                        final double missing = ((result['min_amount'] as num) - (result['current_amount'] as num)).toDouble();
                                        msg = l10n.translate('promo_missing_amount_error').replaceAll('%s', _fC(missing));
                                      }
                                      TopNotification.show(context, msg, isError: true);
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isPromoApplied ? Colors.grey : const Color(0xFFFF7A00),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: Text(_isPromoApplied ? l10n.translate('applied') : l10n.translate('apply'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                        if (_isPromoApplied) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _promoType == 'percent' 
                                      ? "Sizga ${_promoValue?.toInt()}% chegirma berildi"
                                      : "Sizga ${_fC(_promoValue ?? 0)} ${l10n.translate('som')} chegirma berildi",
                                    style: GoogleFonts.montserrat(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ], isDark);
                    },
                  ),

                  // Payment Method - Consolidated with Summary
                  _buildCard([
                    // Summary Section at the top of Payment Card
                    if (discountedTotalValue > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.translate('discounted_products'), style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${_fC(discountedTotalValue)} ${l10n.translate('som')}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(l10n.translate('non_discounted_products'), style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_isPromoApplied && (_promoTarget?.toLowerCase() == 'products' || _promoTarget == null)) ...[
                              Text('${_fC(nonDiscountedTotalValue)} ${l10n.translate('som')}', 
                                style: GoogleFonts.montserrat(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                              Text('- ${_fC(_discountAmount)} ${l10n.translate('som')}', 
                                style: GoogleFonts.montserrat(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('${_fC(nonDiscountedTotalValue - _discountAmount)} ${l10n.translate('som')}', 
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ] else ...[
                              Text('${_fC(nonDiscountedTotalValue)} ${l10n.translate('som')}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, thickness: 0.5),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.translate('delivery_fee'), style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 13)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_isPromoApplied && _promoTarget == 'delivery') ...[
                              Text('${_fC(cart.calculateDeliveryFee(cart.totalAmount))} ${l10n.translate('som')}', 
                                style: GoogleFonts.montserrat(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                              Text('- ${_fC(_discountAmount)} ${l10n.translate('som')}', 
                                style: GoogleFonts.montserrat(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('${_fC(cart.calculateDeliveryFee(cart.totalAmount) - _discountAmount)} ${l10n.translate('som')}', 
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ] else ...[
                              Text(_deliveryMethod == 'delivery' ? '${_fC(cart.calculateDeliveryFee(cart.totalAmount))} ${l10n.translate('som')}' : l10n.translate('free'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                            ],
                          ],
                        ),
                      ],
                    ),
                    // Keyingi dastavka pog'onasi haqida ma'lumot
                    if (_deliveryMethod == 'delivery') ...[
                      Builder(
                        builder: (context) {
                          final nextTier = cart.getNextTierInfo(cart.totalAmount);
                          if (nextTier == null) return const SizedBox.shrink();
                          
                          return Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (nextTier['is_free'] ? Colors.green : const Color(0xFFFF7A00)).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: (nextTier['is_free'] ? Colors.green : const Color(0xFFFF7A00)).withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  nextTier['is_free'] ? Icons.redeem_rounded : Icons.info_outline_rounded,
                                  color: nextTier['is_free'] ? Colors.green : const Color(0xFFFF7A00),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    nextTier['is_free'] 
                                      ? "Yana ${_fC(nextTier['needed'])} ${l10n.translate('som')} xarid qiling va bepul dastavkaga ega bo'ling!"
                                      : "Yana ${_fC(nextTier['needed'])} ${l10n.translate('som')} xarid qiling va dastavka narxini ${_fC(nextTier['next_price'])} ${l10n.translate('som')}ga tushiring!",
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: nextTier['is_free'] ? Colors.green[800] : const Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.translate('total_amount_checkout'), style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                        Text('${_fC(total)} ${l10n.translate('som')}', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFFFF7A00))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDashedDivider(isDark),
                    const SizedBox(height: 20),

                    _buildSectionTitle(l10n.translate('payment_type'), isDark),
                    _buildSelectableOption(
                      title: l10n.translate('cash_payment'),
                      emojiIcon: '💵',
                      isSelected: _paymentMethod == 'cash',
                      onTap: () => setState(() => _paymentMethod = 'cash'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildSelectableOption(
                      title: l10n.translate('card_payment'),
                      emojiIcon: '💳',
                      isSelected: _paymentMethod == 'card',
                      onTap: () {
                        // Keep cash only for now
                      },
                      isDark: isDark,
                      badge: l10n.translate('coming_soon'),
                    ),

                    if (_paymentMethod == 'card') ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              keyboardType: TextInputType.number,
                              maxLength: 19,
                              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                              decoration: InputDecoration(
                                labelText: l10n.translate('card_number'),
                                labelStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, letterSpacing: 0),
                                counterText: '',
                                prefixIcon: const Icon(Icons.credit_card, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    maxLength: 5,
                                    style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      labelText: l10n.translate('expire_date'),
                                      hintText: 'OO/YY',
                                      labelStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13),
                                      hintStyle: GoogleFonts.montserrat(color: Colors.grey[400], fontSize: 14),
                                      counterText: '',
                                      prefixIcon: const Icon(Icons.calendar_today_rounded, color: Colors.grey, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    maxLength: 3,
                                    obscureText: true,
                                    style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      labelText: 'CVV',
                                      labelStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13),
                                      counterText: '',
                                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ], isDark),
                  const SizedBox(height: 24),
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.watch<LocalizationProvider>().translate('total_amount_checkout'), style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                      Text(
                        '${_fC(total)} ${context.watch<LocalizationProvider>().translate('som')}',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF7A00),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _regionSelected && !_isRegionActive(_selectedRegion) ? Colors.redAccent : const Color(0xFFFF7A00),
                        disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[400],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: (_isSubmitting || (_deliveryMethod == 'delivery' && (!_regionSelected || !_isRegionActive(_selectedRegion)))) ? null : () async {
                        if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
                          TopNotification.show(context, context.read<LocalizationProvider>().translate('fill_name_phone'), isError: true);
                          return;
                        }

                        setState(() => _isSubmitting = true);
                        
                        // DEBUG LOGGING
                        final selectedItems = cart.items.values.where((item) => item.isSelected).toList();
                        debugPrint('--- CHECKOUT START ---');
                        debugPrint('Total Cart Items: ${cart.items.length}');
                        debugPrint('Selected Items for Order: ${selectedItems.length}');
                        for (var item in selectedItems) {
                          debugPrint(' - ID: ${item.id}, Title: ${item.title}, Qty: ${item.quantity}');
                        }

                        try {
                          final success = await SupabaseService.placeOrder(
                            name: _nameController.text,
                            phone: _phoneController.text,
                            address: _deliveryMethod == 'delivery' ? ("$_geocodedAddress\n${_addressController.text}") : l10n.translate('pickup_at_main_store'),
                            totalAmount: total,
                            deliveryFee: deliveryFee,
                            discountAmount: _discountAmount,
                            items: cart.items.values.where((item) => item.isSelected).map((item) => {
                              'product_id': item.id, // Bu yerda biz ID-ni Home/Category screenlarda mapp qilganmiz
                              'quantity': item.quantity,
                              'price': double.tryParse(item.price.replaceAll(' so\'m', '').replaceAll(' ', '')) ?? 0.0,
                            }).toList(),
                          );

                          if (success) {
                            if (mounted) {
                              // Promo kod ishlatilgan bo'lsa, count-ni oshirish
                              if (_isPromoApplied && _appliedPromoId != null) {
                                final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}'; // Buyurtma ID-si
                                await SupabaseService.incrementPromoUsage(_appliedPromoId!, _phoneController.text, orderId);
                              }

                              TopNotification.show(context, context.read<LocalizationProvider>().translate('checkout_success'));
                              newOrdersCountNotifier.value += 1;
                              cart.clearSelectedItems();
                              Navigator.pop(context); // Go back
                            }
                          } else {
                            if (mounted) {
                              TopNotification.show(context, context.read<LocalizationProvider>().translate('checkout_error'), isError: true);
                            }
                          }
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      },
                      child: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            context.watch<LocalizationProvider>().translate('confirm_order'),
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) {
      text = text.substring(0, 16);
    }
    
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    
    var string = buffer.toString();
    int selectionIndex = newValue.selection.end;
    
    int spacesBefore = 0;
    for (int i = 0; i < selectionIndex && i < newValue.text.length; i++) {
       if (newValue.text[i] == ' ') spacesBefore++;
    }
    
    int charsBefore = selectionIndex - spacesBefore;
    int newSelectionIndex = charsBefore + (charsBefore > 0 ? (charsBefore - 1) ~/ 4 : 0);
    
    if (newSelectionIndex > string.length) {
      newSelectionIndex = string.length;
    }
    if (newSelectionIndex < 0) {
      newSelectionIndex = 0;
    }
    
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
  }
}
