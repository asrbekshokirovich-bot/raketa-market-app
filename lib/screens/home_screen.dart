import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/localization_provider.dart';
import 'category_products_screen.dart';
import 'search_screen.dart';
import 'announcements_screen.dart';

import '../main.dart';
import '../widgets/product_bottom_sheet.dart';
import '../widgets/top_notification.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int, {bool scrollToProducts})? onNavigate;
  final bool scrollToProducts;
  
  const HomeScreen({super.key, this.onNavigate, this.scrollToProducts = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _productsKey = GlobalKey();
  final GlobalKey<_AutoScrollingBannersState> _bannersKey = GlobalKey<_AutoScrollingBannersState>();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _newProducts = [];
  bool _isLoading = true;
  int _unreadAnnouncements = 0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _checkUnreadAnnouncements();
  }

  Future<void> _checkUnreadAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenCount = prefs.getInt('last_seen_announcements_count') ?? 0;
    
    final allAnnouncements = await SupabaseService.fetchAnnouncements();
    final total = allAnnouncements.length;
    
    if (mounted) {
      setState(() {
        _unreadAnnouncements = total > lastSeenCount ? (total - lastSeenCount) : 0;
      });
    }
  }

  Future<void> _fetchProducts() async {
    try {
      _bannersKey.currentState?.reloadBanners();
      final response = await SupabaseService.client
          .from('vw_product_listings_with_stock')
          .select()
          .eq('status', 'Active')
          .order('created_at', ascending: false);
      
      if (mounted) {
        final List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(response);
        
        setState(() {
          _products = rawList.map((raw) {
            final productData = raw['products'] as Map<String, dynamic>?;

            // CRM-da narxlar string ko'rinishida saqlangan bo'lishi mumkin (masalan: "450,000 UZS")
            // Biz buni tozalab, formatlaymiz.
            String rawPrice = raw['price']?.toString() ?? productData?['price']?.toString() ?? '0';
            String rawOldPrice = raw['original_price']?.toString() ?? productData?['original_price']?.toString() ?? '0';
            
            // Faqat raqamlarni olamiz
            int price = int.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            int oldPrice = int.tryParse(rawOldPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            
            // Narxni formatlash (masalan: 15000 -> 15 000 so'm)
            String formatPrice(int p) {
              return '${p.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} so\'m';
            }

            // Rasmlar array bo'lishi mumkin - mahsulot datasi join-dan kelishi mumkin
            String? imageUrl;
            final rawImages = raw['images'] ?? productData?['images'];
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
              final rawImage = raw['image_url'] ?? raw['image'] ?? productData?['image_url'] ?? productData?['image'];
              imageUrl = (rawImage is List && rawImage.isNotEmpty) 
                  ? rawImage[0].toString() 
                  : rawImage?.toString();
            }

            // Final trim to ensure no whitespace causes issues
            imageUrl = imageUrl?.trim();

            return {
              'id': raw['id'],
              'title': raw['name'] ?? raw['title'] ?? productData?['name'] ?? 'Nomsiz',
              'subtitle': raw['description'] ?? raw['subtitle'] ?? productData?['description'] ?? '',
              'price': formatPrice(price),
              'oldPrice': oldPrice > 0 ? formatPrice(oldPrice) : null,
              'discountBadge': (raw['discount_percent'] != null && raw['discount_percent'].toString() != '0')
                  ? '${raw['discount_percent']}% CHEGIRMA'
                  : (productData?['discount_percent'] != null && productData?['discount_percent'].toString() != '0')
                      ? '${productData?['discount_percent']}% CHEGIRMA'
                      : (oldPrice > price && oldPrice > 0) 
                          ? '${((oldPrice - price) / oldPrice * 100).round()}% CHEGIRMA' 
                          : null,
              'isDiscounted': (raw['discount_percent'] != null && raw['discount_percent'].toString() != '0') || (oldPrice > price && price > 0),
              'image': imageUrl ?? '',
              'images': rawImages is List ? rawImages : (imageUrl != null ? [imageUrl] : []),
              'unit': raw['unit']?.toString() ?? productData?['unit']?.toString() ?? 'ta',
              'sku': raw['sku']?.toString() ?? productData?['sku']?.toString() ?? '',
              'original_category': raw['category'] ?? productData?['category'] ?? '',
              'created_at': raw['created_at'],
              'stock': int.tryParse(raw['stock']?.toString() ?? '0') ?? 0,
              'min_stock': int.tryParse(raw['min_stock']?.toString() ?? '10') ?? 10,
            };
          }).toList();

          // 12 soatlik "Yangi maxsulotlar" filtri
          final now = DateTime.now();
          _newProducts = rawList.where((raw) {
            if (raw['created_at'] == null) return false;
            try {
              final createdAt = DateTime.parse(raw['created_at'].toString());
              final difference = now.difference(createdAt);
              return difference.inHours <= 12;
            } catch (e) {
              return false;
            }
          }).map((raw) {
            // Asosiy mapping bilan bir xil bo'lishi uchun (_products kabi)
            // Bu yerda takrorlash o'rniga helper funksiya ishlatsa ham bo'ladi, 
            // lekin hozircha soddalik uchun _products ichidan izlaymiz.
            return _products.firstWhere((p) => p['id'] == raw['id']);
          }).toList();

          _isLoading = false;
        });
        debugPrint('Successfully mapped ${_products.length} product listings, ${_newProducts.length} are new (within 12h)');
      }
    } catch (e) {
      debugPrint('Error fetching product listings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF7A00),
          ),
        ),
      );
    }

    if (widget.scrollToProducts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_productsKey.currentContext != null) {
          Scrollable.ensureVisible(
            _productsKey.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        toolbarHeight: 75,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/images/raketa_logo.png', width: 65, height: 65),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Raketa ',
                            style: TextStyle(color: Color(0xFFFF7A00)),
                          ),
                          TextSpan(
                            text: 'Market app',
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    context.watch<LocalizationProvider>().translate('qulay_tezkor'),
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _unreadAnnouncements > 0
                ? Badge(
                    label: Text('$_unreadAnnouncements'),
                    backgroundColor: const Color(0xFFE50914), // Red tag
                    child: const Icon(Icons.notifications_none, size: 28),
                  )
                : const Icon(Icons.notifications_none, size: 28),
            color: isDark ? Colors.white : Colors.black87,
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
              _checkUnreadAnnouncements(); // Refresh count after checking
            },
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, child) {
              final isDarkMode = currentMode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isDarkMode ? Icons.light_mode : Icons.dark_mode_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () {
                  themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
                },
                tooltip: isDarkMode ? context.watch<LocalizationProvider>().translate('kunduzgi_rejim') : context.watch<LocalizationProvider>().translate('tungi_rejim'),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _checkUnreadAnnouncements();
          await _fetchProducts();
        },
        color: const Color(0xFFFF7A00),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchScreen(onNavigate: widget.onNavigate)),
                  );
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search, 
                        color: isDark ? Colors.white70 : Colors.black54, 
                        size: 22
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.watch<LocalizationProvider>().translate('mahsulot_toifa_qidirish'),
                        style: GoogleFonts.montserrat(
                          color: isDark ? Colors.grey[400] : Colors.grey[600], 
                          fontSize: 13, 
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Banners (16:9 Aspect Ratio)
            SizedBox(
              height: 220, // Increased height for 16:9 proportion (197 + dots padding)
              child: _AutoScrollingBanners(key: _bannersKey),
            ),
            // Categories (Barcha 12 ta kategoryani ko'rsatamiz - Sync with Catalog)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.watch<LocalizationProvider>().translate('kategoriyalar'),
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            _AutoScrollingCategories(
              categories: const [
                'Chegirma', 'Oziq-ovqat', 'Ichimliklar', 'Shirinliklar', 
                'Mevalar', 'Sabzavotlar', 'Go\'sht', 'Sut mahsulotilari', 
                'Non va un', 'Maishiy kimyo', 'Bolalar oziq-ovqati', 
                'Go\'zallik', 'Uy hayvonlari'
              ],
            ),
            // Yangi Maxsulotlar (Horizontal) - Faqat oxirgi 12 soatliklar bo'lsa ko'rsatamiz
            if (_newProducts.isNotEmpty) ...[
              Padding(
                key: _productsKey,
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 12),
                child: Text(
                  context.watch<LocalizationProvider>().translate('yangi_maxsulotlar'),
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              SizedBox(
                height: (MediaQuery.of(context).size.width - 48) / 2 + 76,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _newProducts.length,
                  itemBuilder: (context, index) {
                    final product = _newProducts[index];
                    final double gridItemWidth = (MediaQuery.of(context).size.width - 32 - 16) / 2;
                    
                    return Container(
                      width: gridItemWidth,
                      margin: const EdgeInsets.only(right: 16),
                      child: _buildProductCard(context, isDark, product),
                    );
                  },
                ),
              ),
            ],
            // Maxsulotlar (Grid)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 12),
              child: Text(
                context.watch<LocalizationProvider>().translate('maxsulotlar'),
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: (MediaQuery.of(context).size.width - 48) / 2 + 76, // Kenglikka qarab moslashuvshan qat'iy balandlik
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final product = _products[index];
                return _buildProductCard(context, isDark, product);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildProductCard(BuildContext context, bool isDark, Map<String, dynamic> product) {
    final bool isDiscounted = product['isDiscounted'] ?? false;
    
    return GestureDetector(
      onTap: () {
        debugPrint('--- PRODUCT CLICKED: ${product['title']} ---');
        showProductBottomSheet(context, isDark, product, widget.onNavigate);
      },
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
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                          return Container(
                            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
                            child: const Center(
                              child: Icon(Icons.shopping_bag_outlined, size: 50, color: Colors.grey),
                            ),
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
                      bottom: 8,
                      left: 8,
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
                  // Title with fixed height for 1 line
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
                  // Price Section
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

class _AutoScrollingBanners extends StatefulWidget {
  const _AutoScrollingBanners({super.key});

  @override
  State<_AutoScrollingBanners> createState() => _AutoScrollingBannersState();
}

class _AutoScrollingBannersState extends State<_AutoScrollingBanners> {
  final PageController _pageController = PageController(initialPage: 1000, viewportFraction: 0.9);
  Timer? _timer;
  int _currentPage = 1000;
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    reloadBanners();
  }

  Future<void> reloadBanners() async {
    final banners = await SupabaseService.fetchBanners();
    if (mounted) {
      setState(() {
        _banners = banners;
        _isLoading = false;
      });
      _startTimer();
    }
  }

  void _startTimer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
        if (!mounted || !_pageController.hasClients || _banners.isEmpty) {
          timer.cancel();
          return;
        }
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
        ),
      );
    }
    
    if (_banners.isEmpty) {
      return const SizedBox.shrink(); // Hide banners if there are none
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              final realIndex = index % _banners.length;
              final banner = _banners[realIndex];
              final imageUrl = banner['image_url'] ?? banner['image'] ?? banner['url'];
              
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.2)).clamp(0.0, 1.0);
                  } else if (index != _currentPage) {
                    value = 0.8;
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 197, // 16:9 aspect ratio
                      width: Curves.easeOut.transform(value) * 350,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ]
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Builder(builder: (context) {
                      if (imageUrl == null || imageUrl.toString().isEmpty) {
                        return Container(color: const Color(0xFFFF7A00));
                      }
                      return CachedNetworkImage(
                        imageUrl: imageUrl.toString(),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00), strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFFF7A00),
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 40)),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) {
            final isActive = (_currentPage % _banners.length) == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: isActive ? 24 : 8,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFF7A00) : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _AutoScrollingCategories extends StatefulWidget {
  final List<String> categories;
  const _AutoScrollingCategories({required this.categories});

  @override
  State<_AutoScrollingCategories> createState() => _AutoScrollingCategoriesState();
}

class _AutoScrollingCategoriesState extends State<_AutoScrollingCategories> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _isUserScrolling = false;

  // Helper funksiya kategoriyalarga mos rang va icon tanlash uchun
  Map<String, dynamic> _getCategoryStyle(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('chegirma')) return {'icon': Icons.local_offer_outlined, 'color': const Color(0xFFE50914)};
    if (lowerTitle.contains('oziq-ovqat')) return {'icon': Icons.flatware_outlined, 'color': const Color(0xFFFF7A00)};
    if (lowerTitle.contains('ichimliklar')) return {'icon': Icons.local_drink_outlined, 'color': const Color(0xFF007AFF)};
    if (lowerTitle.contains('shirinliklar')) return {'icon': Icons.cake_outlined, 'color': const Color(0xFFFF2D55)};
    if (lowerTitle.contains('mevalar')) return {'icon': Icons.apple_outlined, 'color': const Color(0xFF34C759)};
    if (lowerTitle.contains('sabzavotlar')) return {'icon': Icons.eco_outlined, 'color': const Color(0xFF34C759)};
    if (lowerTitle.contains('go\'sht')) return {'icon': Icons.kebab_dining_outlined, 'color': const Color(0xFF8E4832)};
    if (lowerTitle.contains('sut mahsulotilari')) return {'icon': Icons.water_drop_outlined, 'color': const Color(0xFF5AC8FA)};
    if (lowerTitle.contains('non va un')) return {'icon': Icons.bakery_dining_outlined, 'color': const Color(0xFFD1A172)};
    if (lowerTitle.contains('maishiy kimyo')) return {'icon': Icons.sanitizer_outlined, 'color': const Color(0xFF5856D6)};
    if (lowerTitle.contains('bolalar oziq-ovqati')) return {'icon': Icons.child_care_outlined, 'color': const Color(0xFFFF9500)};
    if (lowerTitle.contains('go\'zallik')) return {'icon': Icons.spa_outlined, 'color': const Color(0xFFAF52DE)};
    if (lowerTitle.contains('uy hayvonlari')) return {'icon': Icons.pets_outlined, 'color': const Color(0xFF8E8E93)};
    
    return {'icon': Icons.category_outlined, 'color': const Color(0xFFFF7A00)};
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ticker = createTicker((elapsed) {
        if (!mounted) return;

        final deltaMs = (elapsed - _lastElapsed).inMilliseconds;
        _lastElapsed = elapsed;

        if (_scrollController.hasClients && !_isUserScrolling) {
           final double distance = (deltaMs / 1000.0) * 35.0;
           _scrollController.jumpTo(_scrollController.offset + distance);
        }
      });
      _ticker?.start();
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 115,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification && notification.dragDetails != null) {
            // User put finger down to scroll
            _isUserScrolling = true;
          } else if (notification is ScrollEndNotification) {
            // User lifted finger and list stopped moving
            _isUserScrolling = false;
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // large number or null for infinite scroll
          itemBuilder: (context, index) {
            if (widget.categories.isEmpty) {
              return const SizedBox();
            }
            final String title = widget.categories[index % widget.categories.length];
            final style = _getCategoryStyle(title);
            final IconData icon = style['icon'];
            final Color color = style['color'];
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryProductsScreen(categoryTitle: title),
                    ),
                  );
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(
                        icon,
                        color: color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.watch<LocalizationProvider>().translate(title),
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// removed preview annotation
Widget homeScreenPreview() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CartProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7A00)),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      home: HomeScreen(),
    ),
  );
}
