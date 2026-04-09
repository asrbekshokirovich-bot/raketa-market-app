import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/localization_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/product_bottom_sheet.dart';
import '../widgets/top_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  final void Function(int, {bool scrollToProducts})? onNavigate;
  const SearchScreen({super.key, this.onNavigate});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<String> _history = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _results = [];
  Map<String, List<Map<String, dynamic>>> _groupedRelatedProducts = {};
  
  bool _isLoading = false;
  bool _showSuggestions = false;
  bool _showResults = false;
  
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Klaviatura avtomatik chiqishi uchun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Qidiruv tarixini yuklash
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('search_history') ?? [];
    });
  }

  // Qidiruv tarixini saqlash
  Future<void> _saveHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    List<String> currentHistory = prefs.getStringList('search_history') ?? [];
    
    // Dublikatlarni olib tashlash va boshiga qo'shish
    currentHistory.remove(query);
    currentHistory.insert(0, query);
    
    // Maksimal 10 ta tarix
    if (currentHistory.length > 10) {
      currentHistory = currentHistory.sublist(0, 10);
    }
    
    await prefs.setStringList('search_history', currentHistory);
    _loadHistory();
  }

  // Tarixni o'chirish
  Future<void> _deleteHistoryItem(String item) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> currentHistory = prefs.getStringList('search_history') ?? [];
    currentHistory.remove(item);
    await prefs.setStringList('search_history', currentHistory);
    _loadHistory();
  }

  // Jonli qidiruv (Debounced)
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _results = [];
        _groupedRelatedProducts = {};
        _showSuggestions = false;
        _showResults = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query, isAuto: true);
    });
  }

  // To'liq qidiruv
  Future<void> _performSearch(String query, {bool isAuto = false}) async {
    if (query.trim().isEmpty) return;
    
    if (!isAuto) _focusNode.unfocus();
    
    setState(() {
      _isLoading = true;
      _showResults = true;
      _showSuggestions = false;
    });

    if (!isAuto) _saveHistory(query);

    try {
      // Qidiruvni ancha moslashuvchan qilish (Har bir so'z bo'yicha)
      final response = await SupabaseService.client
          .from('product_listings')
          .select()
          .eq('status', 'Active')
          .ilike('name', '%$query%')
          .order('created_at', ascending: false);

      if (mounted) {
        final List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(response);
        
        setState(() {
          _results = rawList.map((raw) {
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
              'category': raw['category'],
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
            };
          }).toList();
        });

        // Multiple category "You might like" fetch logic
        if (_results.isNotEmpty) {
          final Set<String> targetCategories = _results
              .map((r) => r['category']?.toString() ?? '')
              .where((c) => c.isNotEmpty)
              .toSet();
              
          if (targetCategories.isNotEmpty) {
             final relatedResp = await SupabaseService.client
                 .from('product_listings')
                 .select()
                 .eq('status', 'Active')
                 .filter('category', 'in', targetCategories.toList())
                 .limit(100);
                 
             if (mounted) {
                 final relatedRawList = List<Map<String, dynamic>>.from(relatedResp);
                 final resultSetIds = _results.map((r) => r['id'].toString()).toSet();
                 final filteredRawList = relatedRawList.where((raw) => !resultSetIds.contains(raw['id'].toString())).toList();

                 Map<String, List<Map<String, dynamic>>> grouped = {};
                 
                 for (var raw in filteredRawList) {
                    final cat = raw['category']?.toString() ?? 'Boshqa';
                    String rawPrice = raw['price']?.toString() ?? '0';
                    String rawOldPrice = raw['original_price']?.toString() ?? '0';
                    int price = int.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    int oldPrice = int.tryParse(rawOldPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    String formatPrice(int p) => '${p.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} so\'m';
                    String? imageUrl;
                    final rImages = raw['images'];
                    if (rImages is List && rImages.isNotEmpty) imageUrl = rImages[0].toString();
                    if (imageUrl == null || imageUrl.isEmpty) {
                      final rImage = raw['image_url'] ?? raw['image'];
                      imageUrl = (rImage is List && rImage.isNotEmpty) ? rImage[0].toString() : rImage?.toString();
                    }
                    imageUrl = imageUrl?.trim();

                    final mapObj = {
                      'id': raw['id'],
                      'title': raw['name'] ?? raw['title'] ?? 'Nomsiz',
                      'subtitle': raw['description'] ?? raw['subtitle'] ?? '',
                      'price': formatPrice(price),
                      'oldPrice': oldPrice > price && price > 0 ? formatPrice(oldPrice) : null,
                      'image': imageUrl ?? 'assets/images/placeholder.png',
                      'images': raw['images'] is List ? raw['images'] : (imageUrl != null ? [imageUrl] : []),
                      'discountBadge': (raw['discount_percent'] != null && raw['discount_percent'].toString() != '0')
                          ? '${raw['discount_percent']}% CHEGIRMA'
                          : (oldPrice > price && price > 0) ? '${((oldPrice - price) / oldPrice * 100).round()}% CHEGIRMA' : null,
                      'isDiscounted': (raw['discount_percent'] != null && raw['discount_percent'].toString() != '0') || (oldPrice > price && price > 0),
                      'unit': raw['unit']?.toString() ?? 'ta',
                    };
                    
                    if (!grouped.containsKey(cat)) {
                      grouped[cat] = [];
                    }
                    if (grouped[cat]!.length < 10) {
                       grouped[cat]!.add(mapObj);
                    }
                 }
                 
                 setState(() {
                    // Sifat filtri - faqat mahsuloti bor guruhlarni saqlab qolamiz
                    grouped.removeWhere((key, value) => value.isEmpty);
                    _groupedRelatedProducts = grouped;
                 });
             }
          } else {
             if (mounted) setState(() => _groupedRelatedProducts = {});
          }
        } else {
           if (mounted) setState(() => _groupedRelatedProducts = {});
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error performing search: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: context.watch<LocalizationProvider>().translate('qidirish'),
            hintStyle: GoogleFonts.montserrat(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
            suffixIcon: _isLoading
                ? Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.all(14),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFFF7A00),
                    ),
                  )
                : _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _showResults = false;
                            _showSuggestions = false;
                            _groupedRelatedProducts = {};
                          });
                        },
                      )
                    : null,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _performSearch,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: _buildBody(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_showResults) {
      if (_results.isEmpty && !_isLoading) {
        return KeyedSubtree(
          key: const ValueKey('empty_results'),
          child: _buildEmptyState(isDark, context.watch<LocalizationProvider>().translate('hech_narsa_topilmadi')),
        );
      }
      return KeyedSubtree(
        key: ValueKey('results_${_results.length}_${_groupedRelatedProducts.length}_$_isLoading'),
        child: _buildResultsGrid(isDark),
      );
    }
    
    if (_searchController.text.isNotEmpty && _showSuggestions) {
      return KeyedSubtree(
        key: const ValueKey('suggestions'),
        child: _buildSuggestionsList(isDark),
      );
    }
    
    return KeyedSubtree(
      key: const ValueKey('history'),
      child: _buildHistoryList(isDark),
    );
  }

  Widget _buildHistoryList(bool isDark) {
    if (_history.isEmpty) {
      return _buildEmptyState(isDark, context.watch<LocalizationProvider>().translate('qidiruv_tarixini_boshlang'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            context.watch<LocalizationProvider>().translate('qidiruv_tarixi'),
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey, size: 20),
                title: Text(
                  item,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => _deleteHistoryItem(item),
                ),
                onTap: () {
                  _searchController.text = item;
                  _performSearch(item);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsList(bool isDark) {
    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final name = _suggestions[index]['name'];
        return ListTile(
          leading: const Icon(Icons.search, color: Colors.grey, size: 20),
          title: Text(
            name,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          onTap: () {
            _searchController.text = name;
            _performSearch(name);
          },
        );
      },
    );
  }

  Widget _buildResultsGrid(bool isDark) {
    if (_results.isEmpty) return const SizedBox.shrink();

    final cardHeight = (MediaQuery.of(context).size.width - 48) / 2 + 76;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
            child: Text(
              context.watch<LocalizationProvider>().translate('natija'),
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                return Container(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  child: _buildProductCard(context, isDark, _results[index]),
                );
              },
            ),
          ),
          if (_groupedRelatedProducts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                context.watch<LocalizationProvider>().translate('you_might_like'),
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            ..._groupedRelatedProducts.entries.map((entry) {
              final String categoryName = entry.key;
              final List<Map<String, dynamic>> products = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF7A00).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        context.watch<LocalizationProvider>().translate(categoryName),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF7A00),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: cardHeight,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: (MediaQuery.of(context).size.width - 48) / 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          child: _buildProductCard(context, isDark, products[index]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ]
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ],
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
                          product['discountBadge'] ?? '',
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
                          product['oldPrice'] ?? '',
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
                    product['price'] ?? '',
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
                      final bool inCart = cart.isInCart(productId);

                      return SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: inCart
                                ? (isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE8F5E9))
                                : (isDark ? const Color(0xFF333333) : Colors.black),
                            foregroundColor: inCart
                                ? (isDark ? Colors.greenAccent : Colors.green)
                                : Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
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
                            if (widget.onNavigate != null) {
                              widget.onNavigate!(2); // 2 is Cart Screen index
                              Navigator.pop(context); // Go back then switch tab
                            }
                          },
                          icon: Icon(inCart ? Icons.shopping_cart : Icons.shopping_cart_outlined, size: 14),
                          label: Text(
                            inCart ? context.watch<LocalizationProvider>().translate('otish') : context.watch<LocalizationProvider>().translate('savatga'),
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
