import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import 'category_products_screen.dart';

class CatalogScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const CatalogScreen({super.key, this.onNavigate});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _allCategories = [
    {'title': 'Chegirma', 'icon': Icons.local_offer_outlined, 'color': const Color(0xFFE50914)},
    {'title': 'Oziq-ovqat', 'icon': Icons.flatware_outlined, 'color': const Color(0xFFFF7A00)},
    {'title': 'Ichimliklar', 'icon': Icons.local_drink_outlined, 'color': const Color(0xFF007AFF)},
    {'title': 'Shirinliklar', 'icon': Icons.cake_outlined, 'color': const Color(0xFFFF2D55)},
    {'title': 'Mevalar', 'icon': Icons.apple_outlined, 'color': const Color(0xFF34C759)},
    {'title': 'Sabzavotlar', 'icon': Icons.eco_outlined, 'color': const Color(0xFF34C759)},
    {'title': 'Go\'sht', 'icon': Icons.kebab_dining_outlined, 'color': const Color(0xFF8E4832)},
    {'title': 'Sut mahsulotilari', 'icon': Icons.water_drop_outlined, 'color': const Color(0xFF5AC8FA)},
    {'title': 'Non va un', 'icon': Icons.bakery_dining_outlined, 'color': const Color(0xFFD1A172)},
    {'title': 'Maishiy kimyo', 'icon': Icons.sanitizer_outlined, 'color': const Color(0xFF5856D6)},
    {'title': 'Bolalar oziq-ovqati', 'icon': Icons.child_care_outlined, 'color': const Color(0xFFFF9500)},
    {'title': 'Go\'zallik', 'icon': Icons.spa_outlined, 'color': const Color(0xFFAF52DE)},
    {'title': 'Uy hayvonlari', 'icon': Icons.pets_outlined, 'color': const Color(0xFF8E8E93)},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Tarjima qilingan nomlar asosida qidiruvni amalga oshirish
    final localizationProvider = context.watch<LocalizationProvider>();
    final filteredCategories = _allCategories.where((cat) {
      final translatedTitle = localizationProvider.translate(cat['title'] as String).toLowerCase();
      return translatedTitle.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          localizationProvider.translate('kategoriyalar'),
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          // Elegant Search Bar in the Catalog itself
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: localizationProvider.translate('katalogdan_qidirish'),
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.3), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.3), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          
          if (filteredCategories.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      localizationProvider.translate('hech_narsa_topilmadi'),
                      style: GoogleFonts.montserrat(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )
                    )
                  ]
                )
              ),
            )
          else
            // Categories Grid
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = filteredCategories[index];
                    final bool isDiscount = cat['title'] == 'Chegirma';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CategoryProductsScreen(
                                categoryTitle: cat['title'] as String,
                                onNavigate: widget.onNavigate,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: isDiscount 
                                ? Border.all(color: Colors.red.withOpacity(0.8), width: 1.5) 
                                : Border.all(
                                    color: isDark ? Colors.grey.withOpacity(0.1) : Colors.transparent,
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: isDiscount 
                                    ? Colors.red.withOpacity(0.15) 
                                    : Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (cat['color'] as Color).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  cat['icon'] as IconData,
                                  color: (cat['color'] as Color),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  localizationProvider.translate(cat['title'] as String),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDiscount 
                                        ? Colors.red 
                                        : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: filteredCategories.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
