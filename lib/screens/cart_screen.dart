import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/top_toast.dart';
import '../providers/cart_provider.dart';
import '../providers/localization_provider.dart';
import '../widgets/product_bottom_sheet.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final void Function(int, {bool scrollToProducts})? onNavigate;

  const CartScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          context.watch<LocalizationProvider>().translate('savat'),
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: const Color(0xFFFF7A00).withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.watch<LocalizationProvider>().translate('savatingiz_bosh'),
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (onNavigate != null) {
                        onNavigate!(0, scrollToProducts: true); 
                      }
                    },
                    child: Text(
                      context.watch<LocalizationProvider>().translate('xaridni_boshlash'),
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final cartItem = cart.items.values.toList()[index];
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
                                  'id': cartItem.id,
                                  'title': cartItem.title,
                                  'subtitle': cartItem.subtitle,
                                  'price': cartItem.price,
                                  'oldPrice': cartItem.oldPrice,
                                  'image': cartItem.imagePath,
                                  'images': cartItem.images,
                                  'discountBadge': cartItem.discountBadge,
                                  'isDiscounted': cartItem.oldPrice != null,
                                },
                              onNavigate,
                              isFromCart: true,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Header Actions Row
                            Row(
                              children: [
                                // Selection Toggle (Save for later)
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    context.read<CartProvider>().toggleSelection(cartItem.id);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          cartItem.isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                          color: cartItem.isSelected ? const Color(0xFFFF7A00) : Colors.grey,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cartItem.isSelected ? context.watch<LocalizationProvider>().translate('xaridga_qoshilgan') : context.watch<LocalizationProvider>().translate('keyinchalikka_qoldirildi'),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: cartItem.isSelected 
                                                ? (isDark ? Colors.white : Colors.black87)
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Delete Button
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  color: const Color(0xFFE50914),
                                  onPressed: () {
                                    context.read<CartProvider>().removeItem(cartItem.id);
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            // Product Info Row
                            Row(
                              children: [
                                // Product Image
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
                                        cartItem.imagePath.startsWith('http')
                                            ? CachedNetworkImage(
                                                imageUrl: cartItem.imagePath,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F6),
                                                  child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00), strokeWidth: 2)),
                                                ),
                                                errorWidget: (context, url, error) => const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                                              )
                                            : Image.asset(
                                                cartItem.imagePath.contains('images/')
                                                    ? (cartItem.imagePath.startsWith('assets/') ? cartItem.imagePath : 'assets/${cartItem.imagePath}')
                                                    : 'assets/images/placeholder.png',
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cartItem.title,
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
                                        cartItem.subtitle,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${context.watch<LocalizationProvider>().translate('narxi')}:',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (cartItem.oldPrice != null)
                                        Text(
                                          cartItem.oldPrice!,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[500],
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      Text(
                                        cartItem.price,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFFF7A00),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Subtotal for this item
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF7A00).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${context.watch<LocalizationProvider>().translate('jami')} ${((double.tryParse(cartItem.price.replaceAll(' so\'m', '').replaceAll(' ', '')) ?? 0.0) * cartItem.quantity).toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]} ")} so\'m',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFFF7A00),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Plus Minus Actions
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      InkWell(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        onTap: () {
                                          context.read<CartProvider>().addItem(
                                            productId: cartItem.id,
                                            title: cartItem.title,
                                            subtitle: cartItem.subtitle,
                                            price: cartItem.price,
                                            oldPrice: cartItem.oldPrice,
                                            imagePath: cartItem.imagePath,
                                            images: cartItem.images,
                                            discountBadge: cartItem.discountBadge,
                                            unit: cartItem.unit,
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          child: const Icon(Icons.add, size: 18, color: Color(0xFFFF7A00)),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Column(
                                          children: [
                                            Text(
                                              '${cartItem.quantity}',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: const Color(0xFFFF7A00),
                                              ),
                                            ),
                                            Text(
                                              cartItem.unit == 'ta' ? '' : cartItem.unit,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                        onTap: () {
                                          context.read<CartProvider>().removeSingleItem(cartItem.id);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          child: Icon(Icons.remove, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
                ),
              ),
              // Bottom Checkout Panel
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
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.watch<LocalizationProvider>().translate('jami_summa'),
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${cart.totalAmount.toStringAsFixed(0)} so\'m',
                            style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
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
                            backgroundColor: const Color(0xFFFF7A00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (cart.totalAmount > 0) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CheckoutScreen(),
                                ),
                              );
                            } else {
                              TopToast.show(context, context.read<LocalizationProvider>().translate('savatda_yetarli_mahsulot_yoq'), color: Colors.redAccent, icon: Icons.error_outline_rounded);
                            }
                          },
                          child: Text(
                            context.watch<LocalizationProvider>().translate('rasmiylashtirish'),
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
