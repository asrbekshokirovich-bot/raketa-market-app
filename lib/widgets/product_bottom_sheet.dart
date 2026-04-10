import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../providers/localization_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/top_notification.dart';
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
    // Local asset logic
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
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 90,
        color: Colors.grey,
      ),
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
    builder: (context) {
      return _ProductBottomSheetContent(
        isDark: isDark,
        product: product,
        images: images,
        onNavigate: onNavigate,
        isFromCart: isFromCart,
      );
    },
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
          // Drag Indicator
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Image Carousel
          SizedBox(
            height: 250,
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildImage(isDark, images[index].toString());
              },
            ),
          ),
          const SizedBox(height: 12),
          
          // Dots Indicator
          if (images.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                final isActive = _currentPage == index;
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
          const SizedBox(height: 16),

          // Info Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnails Row (As requested by user in 2nd image)
                  if (images.length > 1)
                    Container(
                      height: 64,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final isActive = _currentPage == index;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index, 
                                duration: const Duration(milliseconds: 300), 
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 64,
                              height: 64,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive ? const Color(0xFFFF7A00) : Colors.transparent,
                                  width: 2,
                                )
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _buildImage(isDark, images[index].toString()),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product['title'] ?? '',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Consumer<FavoritesProvider>(
                        builder: (context, favorites, child) {
                          final productId = product['product_id']?.toString() ?? product['id']?.toString() ?? product['title'] ?? 'default_id';
                          final bool isFavorite = favorites.isFavorite(productId);
                          return IconButton(
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? const Color(0xFFE50914) : (isDark ? Colors.grey[400] : Colors.black87),
                              size: 28,
                            ),
                            onPressed: () {
                              favorites.toggleFavorite(
                                productId: productId,
                                title: product['title'] ?? '',
                                subtitle: product['subtitle'] ?? '',
                                price: product['price'] ?? '',
                                oldPrice: product['oldPrice'],
                                imagePath: product['image'] ?? 'assets/images/placeholder.png',
                                images: images.map((e) => e.toString()).toList(),
                                discountBadge: product['discountBadge'],
                                unit: product['unit'] ?? 'ta',
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Text(
                        context.watch<LocalizationProvider>().translate('narxi'),
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isDiscounted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product['discountBadge'] ?? '',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    children: [
                      Text(
                        product['price'] ?? '',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFFF7A00) : Colors.black,
                        ),
                      ),
                      /* 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/ ${product['unit'] ?? 'ta'}',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                      */
                      if (isDiscounted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            product['oldPrice'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              decoration: TextDecoration.lineThrough,
                              decorationColor: const Color(0xFFE50914),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    context.watch<LocalizationProvider>().translate('malumot'),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['subtitle'] ?? 'Ma\'lumot kiritilmagan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom Cart Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Consumer<CartProvider>(
                builder: (context, cart, child) {
                  final productId = product['product_id']?.toString() ?? product['id']?.toString() ?? product['title'] ?? 'default_id';
                  final bool inCart = cart.isInCart(productId);

                  return SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inCart ? (isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE8F5E9)) : (isDark ? const Color(0xFFFF7A00) : Colors.black),
                        foregroundColor: inCart ? (isDark ? Colors.greenAccent : Colors.green) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (widget.isFromCart) {
                          Navigator.pop(context);
                          return;
                        }
                        
                        if (!inCart) {
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
                          );
                          TopNotification.show(context, context.read<LocalizationProvider>().translate('savatga_qoshildi'));
                        }
                        
                        Navigator.pop(context);
                        if (widget.onNavigate != null) {
                          widget.onNavigate!(2); // 2 is Cart Screen index
                        }
                      },
                      icon: Icon(inCart ? Icons.shopping_cart : Icons.add_shopping_cart_outlined, size: 22),
                      label: Text(
                        (widget.isFromCart || inCart) 
                            ? context.watch<LocalizationProvider>().translate('otish') 
                            : context.watch<LocalizationProvider>().translate('savatga_qoshish'),
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
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
}

