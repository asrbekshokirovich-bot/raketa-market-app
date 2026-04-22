import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../providers/localization_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/top_notification.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget _buildImage(bool isDark, String? imagePath) {
  if (imagePath == null) return _buildPlaceholderImage(isDark);
  final String path = imagePath.toString().trim();
  final bool isNetwork = path.toLowerCase().startsWith('http');

  if (isNetwork) {
    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.contain,
      width: double.infinity,
      placeholder: (context, url) => _buildPlaceholderImage(isDark),
      errorWidget: (context, url, error) => _buildPlaceholderImage(isDark),
    );
  } else {
    String finalPath = path;
    if (path.toLowerCase().contains('images/')) {
      finalPath = path.startsWith('assets/') ? path : 'assets/$path';
    } else {
      finalPath = 'assets/images/placeholder.png';
    }
    return Image.asset(
      finalPath,
      fit: BoxFit.contain,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(isDark),
    );
  }
}

Widget _buildPlaceholderImage(bool isDark) {
  return Container(
    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
    child: const Center(
      child: Icon(Icons.shopping_bag_outlined, size: 90, color: Colors.grey),
    ),
  );
}

void showProductBottomSheet(
  BuildContext context, 
  bool isDark, 
  Map<String, dynamic> product, 
  void Function(int, {bool scrollToProducts})? onNavigate, {
  bool isFromCart = false,
}) {
  debugPrint('--- OPENING BOTTOM SHEET: ${product['title']} ---');
  final List<dynamic> images = (product['images'] is List) 
      ? product['images'] 
      : (product['image'] != null ? [product['image']] : []);
  if (images.isEmpty) images.add('assets/images/placeholder.png');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProductBottomSheetContent(
      isDark: isDark,
      product: product,
      images: images,
      onNavigate: onNavigate,
      isFromCart: isFromCart,
    ),
  );
}

class _ProductBottomSheetContent extends StatefulWidget {
  final bool isDark;
  final Map<String, dynamic> product;
  final List<dynamic> images;
  final void Function(int, {bool scrollToProducts})? onNavigate;
  final bool isFromCart;

  const _ProductBottomSheetContent({
    required this.isDark,
    required this.product,
    required this.images,
    this.onNavigate,
    this.isFromCart = false,
  });

  @override
  State<_ProductBottomSheetContent> createState() => _ProductBottomSheetContentState();
}

class _ProductBottomSheetContentState extends State<_ProductBottomSheetContent> {
  late PageController _pageController;
  int _currentPage = 0;
  late int _realtimeStock;
  RealtimeChannel? _stockChannel;
  bool _isRefreshing = false;
  Color? _stockColor;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _realtimeStock = int.tryParse(widget.product['stock']?.toString() ?? '0') ?? 0;
    _stockColor = widget.isDark ? Colors.grey[400] : Colors.grey[600];
    _subscribeToStockChanges();
    _refreshStock(widget.product['sku']?.toString() ?? '');
  }

  void _subscribeToStockChanges() {
    final sku = widget.product['sku']?.toString() ?? '';
    if (sku.isEmpty) return;
    debugPrint('--- SUBSCRIBING TO REAL-TIME STOCK FOR SKU: $sku ---');
    _stockChannel = SupabaseService.client.channel('stock_update_$sku');
    _stockChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inventory',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'sku', value: sku),
      callback: (payload) => _handleUpdate(sku),
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'products',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'sku', value: sku),
      callback: (payload) => _handleUpdate(sku),
    ).subscribe();
  }

  void _handleUpdate(String sku) async {
    debugPrint('--- REAL-TIME EVENT RECEIVED FOR SKU: $sku ---');
    _triggerPulse();
    await _refreshStock(sku);
  }

  void _triggerPulse() {
    if (!mounted) return;
    setState(() {
      _stockColor = Colors.green;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _stockColor = widget.isDark ? Colors.grey[400] : Colors.grey[600];
        });
      }
    });
  }

  Future<void> _refreshStock(String sku) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final res = await SupabaseService.client
          .from('vw_product_listings_with_stock')
          .select('stock')
          .eq('sku', sku)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _realtimeStock = int.tryParse(res['stock']?.toString() ?? '0') ?? 0;
        });
        debugPrint('Updated stock for $sku: $_realtimeStock');
      }
    } catch (e) {
      debugPrint('Error refetching stock: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_stockChannel != null) SupabaseService.client.removeChannel(_stockChannel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final product = widget.product;
    final images = widget.images;
    final bool isDiscounted = product['isDiscounted'] ?? false;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              height: 4, width: 40,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          SizedBox(
            height: 250,
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => _buildImage(isDark, images[index].toString()),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == index ? const Color(0xFFFF7A00) : Colors.grey[300]),
            )),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product['title'] ?? '',
                          style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Consumer<FavoritesProvider>(
                        builder: (context, favorites, _) {
                          final productId = product['product_id']?.toString() ?? product['id']?.toString() ?? 'default';
                          final isFavorite = favorites.isFavorite(productId);
                          return IconButton(
                            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey, size: 28),
                            onPressed: () => favorites.toggleFavorite(
                              productId: productId,
                              title: product['title'] ?? '',
                              subtitle: product['subtitle'] ?? '',
                              price: product['price'] ?? '',
                              oldPrice: product['oldPrice'],
                              imagePath: product['image'] ?? '',
                              images: product['images'] != null ? List<String>.from(product['images']) : [],
                              discountBadge: product['discountBadge'],
                              unit: product['unit'] ?? 'ta',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(context.read<LocalizationProvider>().translate('narxi'), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(product['price'] ?? '', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFFFF7A00))),
                      if (isDiscounted && product['oldPrice'] != null) ...[
                        const SizedBox(width: 12),
                        Text(product['oldPrice']!, style: const TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(context.read<LocalizationProvider>().translate('malumot'), style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(product['subtitle'] ?? 'Ma\'lumot kiritilmagan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.5)),
                  _buildStockIndicator(isDark, product),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), offset: const Offset(0, -4), blurRadius: 10)],
            ),
            child: SafeArea(
              child: Consumer<CartProvider>(
                builder: (context, cart, child) {
                  final productId = product['product_id']?.toString() ?? product['id']?.toString() ?? 'default';
                  final bool inCart = cart.isInCart(productId);
                  return SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inCart ? (isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE8F5E9)) : (isDark ? const Color(0xFFFF7A00) : Colors.black),
                        foregroundColor: inCart ? (isDark ? Colors.greenAccent : Colors.green) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (widget.isFromCart) { Navigator.pop(context); return; }
                        if (!inCart) {
                          cart.addItem(
                            productId: productId, title: product['title'] ?? '', subtitle: product['subtitle'] ?? '',
                            price: product['price'] ?? '', oldPrice: product['oldPrice'], imagePath: product['image'] ?? '',
                            images: product['images'], discountBadge: product['discountBadge'], unit: product['unit'],
                            sku: product['sku']?.toString(),
                            stock: int.tryParse(product['stock']?.toString() ?? '0') ?? 0,
                            min_stock: int.tryParse(product['min_stock']?.toString() ?? '10') ?? 10,
                          );
                          TopNotification.show(context, context.read<LocalizationProvider>().translate('savatga_qoshildi'));
                        }
                        Navigator.pop(context);
                        if (widget.onNavigate != null) widget.onNavigate!(2);
                      },
                      icon: Icon(inCart ? Icons.shopping_cart : Icons.add_shopping_cart_outlined, size: 22),
                      label: Text(
                        (widget.isFromCart || inCart) ? context.watch<LocalizationProvider>().translate('otish') : context.watch<LocalizationProvider>().translate('savatga_qoshish'),
                        style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockIndicator(bool isDark, Map<String, dynamic> product) {
    final int stock = _realtimeStock;
    final int minStock = product['min_stock'] ?? 10;
    final String unit = product['unit'] ?? 'ta';

    if (stock == 0) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.2))),
        child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Text("Sotuvda mavjud emas", style: GoogleFonts.montserrat(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    if (stock <= minStock) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFFF7A00).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFF7A00).withOpacity(0.2))),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF7A00), size: 20),
          const SizedBox(width: 10),
          Text("Kam qoldi, ulgurib qoling", style: GoogleFonts.montserrat(color: const Color(0xFFFF7A00), fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(children: [
        Icon(Icons.inventory_2_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 8),
        Text("$_realtimeStock $unit xarid qilishingiz mumkin", style: GoogleFonts.montserrat(color: _stockColor, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
