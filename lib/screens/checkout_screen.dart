import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/top_notification.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/localization_provider.dart';
import '../services/supabase_service.dart';
import '../main.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final MapController _mapController = MapController();
  final LatLng _storeLocation = const LatLng(41.332306, 69.282835);
  
  Timer? _debounce;
  String _geocodedAddress = '';
  LatLng _currentMapPosition = const LatLng(41.2995, 69.2401);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_geocodedAddress.isEmpty) {
      _geocodedAddress = context.read<LocalizationProvider>().translate('searching_address');
    }
  }

  Future<void> _fetchAddressInfo(LatLng coords) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18&addressdetails=1&accept-language=uz');
      final response = await http.get(url, headers: {'User-Agent': 'com.abulfayiz.supermarket'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};
        final region = address['region'] ?? address['state'] ?? '';
        final city = address['city'] ?? address['town'] ?? address['county'] ?? '';
        final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'] ?? '';

        List<String> parts = [];
        if (region.isNotEmpty) parts.add(region);
        if (city.isNotEmpty && city != region) parts.add(city);
        if (road.isNotEmpty) parts.add(road);

        if (mounted) {
          setState(() {
            _geocodedAddress = parts.isNotEmpty ? parts.join(', ') : context.read<LocalizationProvider>().translate('unknown_area');
            _geocodedAddress += '\n(Koord: ${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)})';
          });
        }
      } else {
        if (mounted) setState(() => _geocodedAddress = context.read<LocalizationProvider>().translate('cannot_determine_address'));
      }
    } catch (e) {
      if (mounted) setState(() => _geocodedAddress = context.read<LocalizationProvider>().translate('connection_error'));
    }
  }

  String _deliveryMethod = 'delivery';
  String _paymentMethod = 'cash';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _promoController = TextEditingController();
  double _discountAmount = 0;
  bool _isPromoApplied = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
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
      // Login qilmagan bo'lsa, sharprefsdan qidiramiz
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
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _promoController.dispose();
    super.dispose();
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
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildAssetLogo(String name, String assetPath, Color fallbackColor, {double scale = 1.0}) {
    return Expanded(
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          assetPath,
          height: 38,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                name,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: fallbackColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
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
                      color: isSelected ? const Color(0xFFFF7A00) : (isDark ? Colors.white : Colors.black87),
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
              const Icon(Icons.check_circle, color: const Color(0xFFFF7A00), size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final deliveryFee = _deliveryMethod == 'delivery' ? 15000.0 : 0.0;
    final subTotal = cart.totalAmount + deliveryFee;
    final total = subTotal - _discountAmount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
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
            fontSize: 26,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
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
                  if (_deliveryMethod == 'delivery')
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
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _currentMapPosition,
                                initialZoom: 14.0,
                                onPositionChanged: (camera, hasGesture) {
                                  if (hasGesture) {
                                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                                    setState(() {
                                      _currentMapPosition = camera.center;
                                      _geocodedAddress = context.read<LocalizationProvider>().translate('searching_address');
                                    });
                                    _debounce = Timer(const Duration(milliseconds: 1500), () {
                                      _fetchAddressInfo(camera.center);
                                    });
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                                ),
                              ],
                            ),
                            // Center absolute pin overlay
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 40.0),
                                child: Icon(Icons.location_on, color: Color(0xFFFF7A00), size: 40),
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
                                  onTap: () {
                                    _mapController.move(const LatLng(41.2995, 69.2401), 16.0);
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
                                color: const Color(0xFFFF7A00).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Color(0xFFFF7A00), size: 24),
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
                      _buildTextField(
                        label: context.watch<LocalizationProvider>().translate('courier_desc'),
                        hint: context.watch<LocalizationProvider>().translate('courier_desc_hint'),
                        prefixIcon: Icons.door_front_door_rounded,
                        controller: _addressController,
                        isDark: isDark,
                      ),
                    ], isDark),

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
                                initialCenter: _storeLocation,
                                initialZoom: 15.0,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
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
                            'Yo\'nalishni boshlash',
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

                  // Payment Method
                  _buildCard([
                    _buildSectionTitle(context.watch<LocalizationProvider>().translate('payment_type'), isDark),
                    _buildSelectableOption(
                      title: context.watch<LocalizationProvider>().translate('cash_payment'),
                      emojiIcon: '💵',
                      isSelected: _paymentMethod == 'cash',
                      onTap: () => setState(() => _paymentMethod = 'cash'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildSelectableOption(
                      title: context.watch<LocalizationProvider>().translate('card_payment'),
                      emojiIcon: '💳',
                      isSelected: _paymentMethod == 'card',
                      onTap: () => setState(() => _paymentMethod = 'card'),
                      isDark: isDark,
                      badge: context.watch<LocalizationProvider>().translate('coming_soon'),
                    ),
                    if (_paymentMethod == 'card') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFF7A00).withOpacity(0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7A00).withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildAssetLogo('Click', 'assets/images/click.png', const Color(0xFF00A2E8), scale: 1.4),
                                _buildAssetLogo('Payme', 'assets/images/payme.png', const Color(0xFF32C7A5), scale: 1.4),
                                _buildAssetLogo('HUMO', 'assets/images/humo.png', const Color(0xFFEB8A2F), scale: 1.6),
                                _buildAssetLogo('UZCARD', 'assets/images/uzcard.png', const Color(0xFF2361B3), scale: 1.4),
                                _buildAssetLogo('VISA', 'assets/images/visa.png', const Color(0xFF1434CB), scale: 0.7),
                              ],
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                                CardNumberFormatter(),
                              ],
                              maxLength: 19,
                              style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2.0),
                              decoration: InputDecoration(
                                labelText: context.watch<LocalizationProvider>().translate('card_number'),
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
                                      labelText: context.watch<LocalizationProvider>().translate('expire_date'),
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
                                      hintText: '***',
                                      labelStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13),
                                      hintStyle: GoogleFonts.montserrat(color: Colors.grey[400], fontSize: 14),
                                      counterText: '',
                                      prefixIcon: const Icon(Icons.lock_rounded, color: Colors.grey, size: 20),
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
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Display basic confirmation fallback if executed statically
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50), // Standard payment green color
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  context.watch<LocalizationProvider>().translate('charge_payment'),
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ], isDark),

                  // Promo Code section
                  _buildCard([
                    _buildSectionTitle(context.watch<LocalizationProvider>().translate('promo_code'), isDark),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            style: GoogleFonts.montserrat(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: context.watch<LocalizationProvider>().translate('enter_promo'),
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_promoController.text.toUpperCase() == 'RAKETA') {
                                setState(() {
                                  _discountAmount = subTotal * 0.1; // 10% discount
                                  _isPromoApplied = true;
                                });
                                TopNotification.show(context, context.read<LocalizationProvider>().translate('promo_applied'));
                              } else {
                                TopNotification.show(context, context.read<LocalizationProvider>().translate('wrong_promo'), isError: true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7A00),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(context.watch<LocalizationProvider>().translate('apply'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    if (_isPromoApplied) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              context.watch<LocalizationProvider>().translate('chegirma_berildi').replaceAll('%s', _discountAmount.toStringAsFixed(0)),
                              style: GoogleFonts.montserrat(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.watch<LocalizationProvider>().translate('products_label'), style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      Text('${cart.totalAmount.toStringAsFixed(0)} so\'m', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.watch<LocalizationProvider>().translate('delivery_fee'), style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      Text(_deliveryMethod == 'delivery' ? '15000 so\'m' : context.watch<LocalizationProvider>().translate('free'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  if (_isPromoApplied) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.watch<LocalizationProvider>().translate('discount_label'), style: GoogleFonts.montserrat(color: Colors.green, fontWeight: FontWeight.w600)),
                        Text('- ${_discountAmount.toStringAsFixed(0)} so\'m', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.green)),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.watch<LocalizationProvider>().translate('total_amount_checkout'), style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_isPromoApplied)
                            Text(
                              '${subTotal.toStringAsFixed(0)} so\'m',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '${total.toStringAsFixed(0)} so\'m',
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFF7A00),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : () async {
                        if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
                          TopNotification.show(context, context.read<LocalizationProvider>().translate('fill_name_phone'), isError: true);
                          return;
                        }

                        setState(() => _isSubmitting = true);

                        try {
                          final success = await SupabaseService.placeOrder(
                            name: _nameController.text,
                            phone: _phoneController.text,
                            address: _deliveryMethod == 'delivery' ? (_geocodedAddress + "\n" + _addressController.text) : "Samovivoz (Asosiy do'kon)",
                            totalAmount: total,
                            items: cart.items.values.map((item) => {
                              'product_id': item.id, // Bu yerda biz ID-ni Home/Category screenlarda mapp qilganmiz
                              'quantity': item.quantity,
                              'price': double.tryParse(item.price.replaceAll(' so\'m', '').replaceAll(' ', '')) ?? 0.0,
                            }).toList(),
                          );

                          if (success) {
                            if (mounted) {
                              TopNotification.show(context, context.read<LocalizationProvider>().translate('checkout_success'));
                              newOrdersCountNotifier.value += 1;
                              cart.clear();
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
