import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/localization_provider.dart';
import '../widgets/top_notification.dart';
import '../services/supabase_service.dart';
import '../widgets/product_bottom_sheet.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryTitle;
  final Function(int)? onNavigate;

  const CategoryProductsScreen({
    super.key, 
    required this.categoryTitle,
    this.onNavigate,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      dynamic query = SupabaseService.client
          .from('vw_product_listings_with_stock')
          .select()
          .eq('status', 'Active');

      if (widget.categoryTitle == 'Chegirma') {
        // Chegirma bo'limi uchun barcha chegirmasi bor mahsulotlarni olamiz
        // discount_percent > 0 yoki original_price > price (pastda Dartda ham tekshiramiz)
        query = query.or('discount_percent.gt.0,original_price.not.is.null');
      } else {
        query = query.eq('category', widget.categoryTitle);
      }

      final response = await query.order('created_at', ascending: false);
      
      if (mounted) {
        final List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(response);
        
        // Agar "Chegirma" bo'lsa, qo'shimcha mantiqiy filtr (narxlar bo'yicha)
        final filteredList = widget.categoryTitle == 'Chegirma' 
          ? rawList.where((raw) {
              int price = int.tryParse(raw['price']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
              int oldPrice = int.tryParse(raw['original_price']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
              int discountPct = int.tryParse(raw['discount_percent']?.toString() ?? '0') ?? 0;
              return discountPct > 0 || (oldPrice > price && price > 0);
            }).toList()
          : rawList;

        setState(() {
          _allProducts = filteredList.map((raw) {
            String rawPrice = raw['price']?.toString() ?? '0';
            String rawOldPrice = raw['original_price']?.toString() ?? '0';
            
            int price = int.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            int oldPrice = int.tryParse(rawOldPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            
            String formatPrice(int p) {
              return '${p.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} so\'m';
            }

            String? imageUrl;
            final rawImages = raw['images'];
            if (rawImages is List && rawImages.isNotEmpty) {
              imageUrl = rawImages[0].toString();
            } else if (rawImages is String && rawImages.trim().startsWith('[')) {
              try {
                final List parsed = json.decode(rawImages);
                if (parsed.isNotEmpty) imageUrl = parsed[0].toString();
              } catch (_) {
                imageUrl = rawImages;
              }
            } else {
              imageUrl = rawImages?.toString();
            }

            if (imageUrl == null || imageUrl.isEmpty) {
              final rawImage = raw['image_url'] ?? raw['image'];
              imageUrl = (rawImage is List && rawImage.isNotEmpty) 
                  ? rawImage[0].toString() 
                  : rawImage?.toString();
            }
            imageUrl = imageUrl?.trim();

            return {
              'id': raw['id'],
              'title': raw['name'] ?? raw['title'] ?? 'Nomsiz',
              'subtitle': raw['description'] ?? raw['subtitle'] ?? '',
              'price': formatPrice(price),
              'oldPrice': oldPrice > price && price > 0 ? formatPrice(oldPrice) : null,
              'image': imageUrl ?? 'assets/images/placeholder.png',
              'images': raw['images'] is List ? raw['images'] : (imageUrl != null ? [imageUrl] : []),
              'discountBadge': (raw['discount_percent'] != null && raw['discount_percent'].toString() != '0')
                  ? '${raw['discount_percent']}% CHEGIRMA'
                  : (oldPrice > price && price > 0) 
                      ? '${((oldPrice - price) / oldPrice * 100).round()}% CHEGIRMA' 
                      : null,
              'isDiscounted': (raw['discount_percent'] != null && raw['discount_percent'].toString() != '0') || (oldPrice > price && price > 0),
              'unit': raw['unit']?.toString() ?? 'ta',
              'sku': raw['sku']?.toString() ?? '',
              'stock': int.tryParse(raw['stock']?.toString() ?? '0') ?? 0,
              'min_stock': int.tryParse(raw['min_stock']?.toString() ?? '10') ?? 10,
            };
          }).toList();
          _filteredProducts = _allProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching category products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) {
          final title = (p['title'] ?? '').toString().toLowerCase();
          final subtitle = (p['subtitle'] ?? '').toString().toLowerCase();
          final search = query.toLowerCase();
          return title.contains(search) || subtitle.contains(search);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          context.watch<LocalizationProvider>().translate(widget.categoryTitle),
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00)))
          : RefreshIndicator(
              onRefresh: _fetchProducts,
              color: const Color(0xFFFF7A00),
              child: Column(
                children: [
                  // Search Bar inside category
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.montserrat(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '${context.watch<LocalizationProvider>().translate(widget.categoryTitle)} ${context.watch<LocalizationProvider>().translate('bolimidan_qidirish')}',
                        hintStyle: GoogleFonts.montserrat(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFFF7A00), size: 22),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 1.8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filteredProducts.isEmpty
                        ? _buildEmptyState(isDark)
                        : GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: (MediaQuery.of(context).size.width - 48) / 2 + 76,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(_filteredProducts[index], isDark);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                context.watch<LocalizationProvider>().translate('hozircha_malumot_yoq'),
                style: GoogleFonts.montserrat(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark) {
    final bool isDiscounted = product['isDiscounted'] ?? false;
    
    return GestureDetector(
      onTap: () => showProductBottomSheet(context, isDark, product, null),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                children: [
                    Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: () {
                        final rawImg = product['image'];
                        String imgPath = '';
                        
                        if (rawImg != null) {
                          imgPath = rawImg.toString().trim();
                          // JSON array bo'lib qolgan bo'lsa tozalash
                          if (imgPath.startsWith('["')) {
                            imgPath = imgPath.replaceAll('["', '').replaceAll('"]', '').split('","')[0];
                          }
                        }

                        if (imgPath.isEmpty || imgPath == 'null' || !imgPath.toLowerCase().startsWith('http')) {
                          return Image.asset(
                            'assets/images/placeholder.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        }

                        return CachedNetworkImage(
                          imageUrl: imgPath,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
                            child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00), strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.shopping_bag_outlined, size: 50, color: Colors.grey),
                          ),
                        );
                      }(),
                    ),
                  ),
                  if (isDiscounted)
                    Positioned(
                      bottom: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE50914).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          (product['discountBadge'] ?? '').toString().replaceAll('CHEGIRMA', context.watch<LocalizationProvider>().translate('chegirma')),
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 4.0, bottom: 2.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 14,
                    child: Text(
                      product['title'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 11, 
                        fontWeight: FontWeight.w700, 
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.watch<LocalizationProvider>().translate('narxi'),
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isDiscounted)
                        Text(
                          (product['oldPrice'] ?? '').toString().replaceAll("so'm", context.watch<LocalizationProvider>().translate('som')),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFFE50914),
                            decorationThickness: 2.0,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (product['price'] ?? '').toString().replaceAll("so'm", context.watch<LocalizationProvider>().translate('som')),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isDark ? const Color(0xFFFF7A00) : Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Consumer<CartProvider>(
                    builder: (context, cart, child) {
                      final productId = product['id']?.toString() ?? product['title'] ?? 'default_id';

                      return SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF333333) : Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            cart.addItem(
                              productId: productId,
                              title: product['title'] ?? '',
                              subtitle: product['subtitle'] ?? '',
                              price: product['price'] ?? '',
                              oldPrice: product['oldPrice'],
                              imagePath: product['image'] ?? 'assets/images/placeholder.png',
                              images: product['images'],
                              discountBadge: product['discountBadge'],
                              unit: product['unit'],
                              sku: product['sku'],
                            );
                            TopNotification.show(context, context.read<LocalizationProvider>().translate('savatga_qoshildi'));
                          },
                          icon: const Icon(Icons.shopping_cart_outlined, size: 14),
                          label: Text(
                            context.watch<LocalizationProvider>().translate('savatga'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
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
