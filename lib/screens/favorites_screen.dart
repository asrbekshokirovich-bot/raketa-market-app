import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/favorites_provider.dart';
import '../providers/localization_provider.dart';
import '../widgets/product_bottom_sheet.dart';

class FavoritesScreen extends StatelessWidget {
  final void Function(int, {bool scrollToProducts})? onNavigate;

  const FavoritesScreen({super.key, this.onNavigate});

  String _fC(dynamic amountStr) {
    double amount = double.tryParse(amountStr.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final formatter = NumberFormat("#,###", "en_US");
    return formatter.format(amount).replaceAll(',', ' ');
  }

  String _t(BuildContext context, String key, [String fallback = '']) {
    return context.read<LocalizationProvider>().translate(key);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          _t(context, 'sevimlilar', 'Sevimlilar'),
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favorites, child) {
          if (favorites.itemCount == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: const Color(0xFFE50914).withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _t(context, 'sevimlilar_bosh', 'Sevimli mahsulotlar yo\'q'),
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: favorites.items.length,
            itemBuilder: (context, index) {
              final favoriteItem = favorites.items.values.toList()[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      offset: const Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      showProductBottomSheet(
                        context,
                        isDark,
                        {
                          'id': favoriteItem.id,
                          'title': favoriteItem.title,
                          'subtitle': favoriteItem.subtitle,
                          'price': favoriteItem.price,
                          'oldPrice': favoriteItem.oldPrice,
                          'image': favoriteItem.imagePath,
                          'images': favoriteItem.images,
                          'discountBadge': favoriteItem.discountBadge,
                          'isDiscounted': favoriteItem.oldPrice != null,
                          'unit': favoriteItem.unit,
                        },
                        onNavigate,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  favoriteItem.imagePath.startsWith('http')
                                      ? CachedNetworkImage(
                                          imageUrl: favoriteItem.imagePath,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          favoriteItem.imagePath.contains('images/')
                                              ? (favoriteItem.imagePath.startsWith('assets/') ? favoriteItem.imagePath : 'assets/${favoriteItem.imagePath}')
                                              : 'assets/images/placeholder.png',
                                          fit: BoxFit.cover,
                                        ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  favoriteItem.title,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _t(context, favoriteItem.subtitle.toLowerCase()),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                if (favoriteItem.oldPrice != null)
                                  Text(
                                    '${_fC(favoriteItem.oldPrice)} ${_t(context, 'som')}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[500],
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  '${_fC(favoriteItem.price)} ${_t(context, 'som')}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFF7A00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Color(0xFFE50914), size: 28),
                            onPressed: () {
                              context.read<FavoritesProvider>().toggleFavorite(
                                productId: favoriteItem.id,
                                title: favoriteItem.title,
                                subtitle: favoriteItem.subtitle,
                                price: favoriteItem.price,
                                oldPrice: favoriteItem.oldPrice,
                                imagePath: favoriteItem.imagePath,
                                images: favoriteItem.images,
                                discountBadge: favoriteItem.discountBadge,
                                unit: favoriteItem.unit,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
