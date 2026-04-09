import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/curved_nav_painter.dart';
import '../providers/cart_provider.dart';
import 'home_screen.dart';
import 'catalog_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import '../main.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _scrollToProductsOnHome = false;
  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onNavigate: _handleNavigate,
        scrollToProducts: _scrollToProductsOnHome,
      ),
      CatalogScreen(onNavigate: _handleNavigate),
      CartScreen(onNavigate: _handleNavigate),
      ProfileScreen(),
    ];
  }

  void _handleNavigate(int index, {bool scrollToProducts = false}) {
    // Asynchronous state update to prevent build phase collisions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentIndex = index;
          _scrollToProductsOnHome = scrollToProducts;
          // Note: IndexedStack doesn't automatically update children properties
          // so if we need to pass scrollToProducts to the existing HomeScreen instance:
          _screens[0] = HomeScreen(
            onNavigate: _handleNavigate,
            scrollToProducts: scrollToProducts,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 95,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Custom Curved Background and Active Indicator (Synced)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              tween: Tween<double>(end: (_currentIndex + 0.5) / 4),
              builder: (context, value, child) {
                // Calculate position for the circle based on animated value
                final double screenWidth = MediaQuery.of(context).size.width;
                final double circleLeft = value * screenWidth - 28;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background Notch
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 80,
                      child: CustomPaint(
                        painter: CurvedNavPainter(
                          x: value,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    
                    // The Bouncy Active Indicator
                    Positioned(
                      left: circleLeft,
                      top: 0,
                      child: Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF7A00),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x4DFF7A00),
                              blurRadius: 15,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _getActiveIconBasedOnPosition(value),
                        ),
                      ),
                    ),

                    // Interactive Icons Row (Static background)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 80,
                      child: Row(
                        children: List.generate(4, (index) {
                           IconData icon;
                           switch (index) {
                             case 0: icon = Icons.home_filled; break;
                             case 1: icon = Icons.grid_view_outlined; break;
                             case 2: icon = Icons.shopping_cart_outlined; break;
                             case 3: icon = Icons.person_outline; break;
                             default: icon = Icons.home_filled;
                           }
                           return _buildNavItem(index, icon, value);
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _getActiveIconBasedOnPosition(double value) {
    // Determine which icon to show based on horizontal progress
    int index = (value * 4 - 0.5).round().clamp(0, 3);
    IconData icon;
    switch (index) {
      case 0: icon = Icons.home_filled; break;
      case 1: icon = Icons.grid_view_rounded; break;
      case 2: icon = Icons.shopping_cart_outlined; break;
      case 3: icon = Icons.person_outline; break;
      default: icon = Icons.home_filled;
    }
    return Icon(icon, key: ValueKey(index), color: Colors.white, size: 28);
  }

  Widget _buildNavItem(int index, IconData iconData, double animatedX) {
    final double itemX = (index + 0.5) / 4;
    final double distance = (animatedX - itemX).abs();
    final bool isNear = distance < 0.1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             AnimatedOpacity(
               duration: const Duration(milliseconds: 200),
               opacity: isNear ? 0.0 : 1.0,
               child: Transform.translate(
                 offset: Offset(0, isNear ? 10 : 0), // Slight sink effect when notch approaches
                 child: Stack(
                   clipBehavior: Clip.none,
                   children: [
                     Icon(
                       iconData,
                       size: 26,
                       color: isDark ? Colors.white70 : Colors.black87,
                     ),
                     if (index == 2) _buildCartBadge(),
                     if (index == 3) _buildProfileBadge(),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBadge() {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        if (cart.itemCount == 0) return const SizedBox.shrink();
        return Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                '${cart.itemCount}',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, height: 1),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileBadge() {
     return ValueListenableBuilder<int>(
      valueListenable: newOrdersCountNotifier,
      builder: (context, newOrdersCount, child) {
        if (newOrdersCount <= 0) return const SizedBox.shrink();
        return Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                '$newOrdersCount',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, height: 1),
              ),
            ),
          ),
        );
      },
    );
  }
}
