import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

class SupabaseService {
  static const String supabaseUrl = 'https://ffddohkyuegzywkepfsk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MjMyMTUsImV4cCI6MjA4OTk5OTIxNX0.8i1POMsCtAxZnLzFuwValTgBGbwqutgLs_7cNxEnzOU';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Foydalanuvchi ma'lumotlarini saqlash (Phone nomeri orqali buyurtmalar tarixini bog'laymiz)
  static Future<void> saveCustomerInfo(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customer_name', name);
    await prefs.setString('customer_phone', phone);
  }

  // Ilovaning umumiy sozlamalarini (Support phone, Telegram) tortib olish
  static Future<Map<String, String>> getAppSettings() async {
    try {
      final response = await client.from('app_settings').select();
      
      Map<String, String> settings = {};
      for (var item in response) {
        if (item.containsKey('key') && item.containsKey('value')) {
          settings[item['key'].toString()] = item['value'].toString();
        } else if (item.containsKey('name') && item.containsKey('value')) {
          settings[item['name'].toString()] = item['value'].toString();
        }
      }
      return settings;
    } catch (e) {
      return {};
    }
  }

  // --- Promo Code Logic ---

  /// Promo kodni bazadan tekshirish va chegirma miqdorini qaytarish
  static Future<Map<String, dynamic>> validatePromoCode({
    required String code,
    required String phone,
    required double subTotal,
    required double deliveryFee,
  }) async {
    try {
      // Diagnostic logging will show in terminal
      // 1. Promo kodni qidirish
      final promoResponse = await client
          .from('promo_codes')
          .select()
          .eq('code', code.trim().toUpperCase())
          .maybeSingle();
      
      print('Promo response for $code: $promoResponse');

      if (promoResponse == null) {
        return {'success': false, 'message_key': 'promo_not_found'};
      }

      final bool isActive = promoResponse['is_active'] ?? false;
      if (!isActive) {
        return {'success': false, 'message_key': 'promo_not_found'};
      }

      // Sanalarni tekshirish
      final startDateStr = promoResponse['start_date'];
      final endDateStr = promoResponse['end_date'];
      final nowDt = DateTime.now().toUtc();

      if (startDateStr != null) {
        final start = DateTime.parse(startDateStr).toUtc();
        if (nowDt.isBefore(start)) {
          return {'success': false, 'message_key': 'promo_not_found'};
        }
      }

      if (endDateStr != null) {
        final end = DateTime.parse(endDateStr).toUtc();
        if (nowDt.isAfter(end)) {
          return {'success': false, 'message_key': 'promo_not_found'};
        }
      }

      final promoId = promoResponse['id'];
      final target = promoResponse['target']; // 'products' | 'delivery'
      final type = promoResponse['type']; // 'percent' | 'amount'
      final value = (promoResponse['value'] as num).toDouble();
      final userLimit = promoResponse['user_limit'] as int;
      final totalLimit = promoResponse['total_limit'] as int;
      final usedCount = promoResponse['used_count'] as int;
      final minAmount = (promoResponse['min_amount'] as num).toDouble();

      // 2. Minimal buyurtma summasini tekshirish
      if (subTotal < minAmount) {
        return {
          'success': false, 
          'message_key': 'promo_min_amount_error',
          'min_amount': minAmount,
          'current_amount': subTotal
        };
      }

      // 3. Umumiy limitni tekshirish
      if (usedCount >= totalLimit) {
        return {'success': false, 'message_key': 'promo_total_limit_reached'};
      }

      // 4. Shaxsiy (Foydalanuvchi) limitni tekshirish
      final usageResponse = await client
          .from('promo_usage')
          .select('id')
          .eq('promo_id', promoId)
          .eq('phone', phone);
      
      if (usageResponse.length >= userLimit) {
        return {'success': false, 'message_key': 'promo_user_limit_reached'};
      }

      // 5. Chegirmani hisoblash
      double discount = 0;
      double baseForDiscount = (target == 'delivery') ? deliveryFee : subTotal;

      // Agar mahsulotlar uchun bo'lsa va chegirmasiz mahsulot yo'q bo'lsa
      if (target == 'products' && subTotal <= 0) {
        return {'success': false, 'message_key': 'promo_eligible_error'};
      }

      if (type == 'percent') {
        discount = (baseForDiscount * value) / 100;
      } else {
        discount = value;
      }

      // Chegirma bazadan oshib ketmasligi kerak
      if (discount > baseForDiscount) {
        discount = baseForDiscount;
      }

      // Agar natija 0 bo'lsa (masalan, delivery targeted but delivery is already free)
      if (discount <= 0) {
        return {'success': false, 'message_key': 'promo_not_found'};
      }

      return {
        'success': true,
        'promo_id': promoId,
        'discount': discount,
        'target': target,
        'type': type,
        'value': value,
      };
    } catch (e) {
      print('Promo validation error: $e');
      return {'success': false, 'message_key': 'promo_system_error'};
    }
  }

  /// Promo kod ishlatilganligini qayd etish
  static Future<void> incrementPromoUsage(String promoId, String phone, String orderId) async {
    try {
      // 1. Promo koddagi used_count ni oshirish
      await client.rpc('increment_promo_count', params: {'promo_id': promoId});
      
      // 2. Foydalanish tarixiga yozish
      await client.from('promo_usage').insert({
        'promo_id': promoId,
        'phone': phone,
        'order_id': orderId,
      });
    } catch (e) {
      // Agar RPC xato bersa (yaratilmagan bo'lsa), oddiy update qilamiz
      try {
        final current = await client.from('promo_codes').select('used_count').eq('id', promoId).single();
        await client.from('promo_codes').update({
          'used_count': (current['used_count'] as int) + 1
        }).eq('id', promoId);
        
        await client.from('promo_usage').insert({
          'promo_id': promoId,
          'phone': phone,
          'order_id': orderId,
        });
      } catch (innerE) {
        print('Error incrementing promo usage: $innerE');
      }
    }
  }

  static Future<Map<String, String?>> getCustomerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('customer_name'),
      'phone': prefs.getString('customer_phone'),
    };
  }

  // Buyurtma berish (Yangi CRM integratsiyasi)
  static Future<bool> placeOrder({
    required String name,
    required String phone,
    required String address,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String coordinates = '',
    double deliveryFee = 0.0,
    double discountAmount = 0.0,
    String? promoCode,
    String? promoType,
    double? promoValue,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson == null) {
        print('USER JSON IS NULL! FAILED TO PLACE ORDER');
        return false;
      }
      final userId = json.decode(userJson)['id'];

      // 1. Kompaniyadagi jami barcha avvalgi buyurtmalar sonini (Global) hisoblash
      final countResponse = await client
          .from('orders')
          .select('id');
      
      final previousCount = (countResponse as List).length;
      final int newOrderIndex = previousCount + 1;
      
      final random5Digit = Random().nextInt(90000) + 10000;
      final orderNumber = 'No-$newOrderIndex • #ID-$random5Digit';
      final courierCodeGenerated = (Random().nextInt(90000) + 10000).toString();
      
      // 2. Orders jadvaliga kiritish va qaytib kelgan ID ni olish
      final orderResponse = await client.from('orders').insert({
        'order_number': orderNumber,
        'user_id': userId,
        'full_name': name,
        'customer_name': name,
        'customer_phone': phone,
        'address': address,
        'coordinates': coordinates,
        'items_count': items.length,
        'total_amount': totalAmount,
        'delivery_fee': deliveryFee,
        'discount_amount': discountAmount,
        'promo_code': promoCode,
        'promo_type': promoType,
        'promo_value': promoValue,
        'status': 'Pending', // CRM qabul qilishi uchun Pending ga o'zgartirildi
        'courier_code': courierCodeGenerated,
      }).select().single();

      final orderId = orderResponse['id'];

      // 2. Order Items jadvaliga kiritish
      // CRM products jadvalidan qidirgani uchun, SKU orqali haqiqiy product ID-larni aniqlaymiz
      final skus = items.map((i) => i['sku']?.toString()).where((s) => s != null && s.isNotEmpty).toList();
      Map<String, String> skuToRealId = {};
      
      if (skus.isNotEmpty) {
        try {
          final productsResponse = await client
              .from('products')
              .select('id, sku')
              .filter('sku', 'in', skus);
          
          for (var p in (productsResponse as List)) {
            if (p['sku'] != null && p['id'] != null) {
              skuToRealId[p['sku'].toString()] = p['id'].toString();
            }
          }
        } catch (skuError) {
          print('SKU lookup error: $skuError');
          // Lookup xato bersa ham davom etamiz (listing ID-ni ishlatamiz)
        }
      }

      final List<Map<String, dynamic>> itemsToInsert = items.map((item) {
        String? resolvedId = skuToRealId[item['sku']?.toString()];
        return {
          'order_id': orderId,
          'product_id': resolvedId ?? item['product_id'], // CRM uchun products.id (topilmasa listing ID)
          'listing_id': item['product_id'], // App uchun product_listings.id (har doim to'g'ri bog'lanadi)
          'product_name': item['product_name'],
          'sku': item['sku'],
          'quantity': item['quantity'],
          'price_at_time': item['price'],
        };
      }).toList();
      await client.from('order_items').insert(itemsToInsert);
      
      // Ma'lumotlarni lokal saqlab qo'yamiz
      await saveCustomerInfo(name, phone);
      
      return true;
    } catch (e) {
      print('Buyurtma berishda xatolik: $e');
      return false;
    }
  }

  // Buyurtmalar tarixini olish
  static Future<List<Map<String, dynamic>>> fetchOrders(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson == null) return [];
      final userId = json.decode(userJson)['id'];

      final response = await client
          .from('orders')
          .select('*, order_items(*, product_listings!listing_id(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Buyurtmalar tarixini yuklashda xatolik: $e');
      return [];
    }
  }

  // Savat ma'lumotlarini yuklash
  static Future<List<Map<String, dynamic>>> getCartItems(String userId) async {
    try {
      final response = await client
          .from('cart_items')
          .select('*, product_listings:product_id!inner(*)') // First join product_listings
          .eq('user_id', userId);
      
      final cartItems = List<Map<String, dynamic>>.from(response);
      if (cartItems.isEmpty) return [];

      // Now we need the stock data from the view for each product
      final productIds = cartItems.map((e) => e['product_id'].toString()).toSet().toList();
      final stockDataResponse = await client
          .from('vw_product_listings_with_stock')
          .select('id, stock, min_stock')
          .inFilter('id', productIds);
      
      final stockMap = { for (var item in stockDataResponse) item['id'].toString() : item };

      // Merge stock data back into the product list
      for (var item in cartItems) {
        if (item['product_listings'] != null) {
          final pId = item['product_id'].toString();
          final stockInfo = stockMap[pId];
          if (stockInfo != null) {
            item['product_listings']['stock'] = stockInfo['stock'];
            item['product_listings']['min_stock'] = stockInfo['min_stock'];
          }
        }
      }

      return cartItems;
    } catch (e) {
      print('Savatni yuklashda xatolik: $e');
      return [];
    }
  }

  // Savatga qo'shish yoki yangilash (Upsert)
  static Future<void> addToCart(String userId, String productId, int quantity) async {
    try {
      await client.from('cart_items').upsert({
        'user_id': userId,
        'product_id': productId,
        'quantity': quantity,
      }, onConflict: 'user_id, product_id');
    } catch (e) {
      print('Savatga qo\'shishda xatolik: $e');
    }
  }

  // Savatdan o'chirish
  static Future<void> removeFromCart(String userId, String productId) async {
    try {
      await client
          .from('cart_items')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      print('Savatdan o\'chirishda xatolik: $e');
    }
  }

  // Savatni tozalash
  static Future<void> clearCart(String userId) async {
    try {
      await client
          .from('cart_items')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      print('Savatni tozalashda xatolik: $e');
    }
  }

  // Sevimlilarni yuklash
  static Future<List<Map<String, dynamic>>> getFavoriteItems(String userId) async {
    try {
      final favoriteRows = await client
          .from('favorite_items')
          .select()
          .eq('user_id', userId);
          
      if ((favoriteRows as List).isEmpty) return [];

      final productIds = favoriteRows.map((e) => e['product_id']).toList();

      final products = await client
          .from('product_listings')
          .select()
          .filter('id', 'in', productIds);

      List<Map<String, dynamic>> result = [];
      for (var fRow in favoriteRows) {
        final matches = (products as List).where((p) => p['id'] == fRow['product_id']);
        
        if (matches.isNotEmpty) {
          final product = matches.first;
          final mappedRow = Map<String, dynamic>.from(fRow);
          mappedRow['product_listings'] = product;
          result.add(mappedRow);
        }
      }
      return result;
    } catch (e) {
      print('Sevimlilarni yuklashda xatolik: $e');
      return [];
    }
  }

  // Sevimlilarni qo'shish
  static Future<void> addFavorite(String userId, String productId) async {
    try {
      await client.from('favorite_items').upsert({
        'user_id': userId,
        'product_id': productId,
      }, onConflict: 'user_id, product_id');
    } catch (e) {
      print('Sevimlilarga qo\'shishda xatolik: $e');
    }
  }

  // Sevimlilardan o'chirish
  static Future<void> removeFavorite(String userId, String productId) async {
    try {
      await client
          .from('favorite_items')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      print('Sevimlilardan o\'chirishda xatolik: $e');
    }
  }

  // Bannerlarni yuklash
  static Future<List<Map<String, dynamic>>> fetchBanners() async {
    try {
      final response = await client
          .from('banners')
          .select()
          .order('sort_order', ascending: true); // CRM dagi 1,2,3 ketma ketlik uchun
      
      print('=== BANNERS DEBUG: $response ===');
      
      final List<Map<String, dynamic>> banners = List<Map<String, dynamic>>.from(response);
      final filteredBanners = banners.where((b) {
        if (!b.containsKey('status') && !b.containsKey('is_active')) return true;
        final status = (b['status'] ?? b['is_active'])?.toString().toLowerCase();
        return status == 'active' || status == 'faol' || status == 'true' || b['status'] == true || b['is_active'] == true || status == '1';
      }).toList();
      
      print('=== FILTERED BANNERS COUNT: ${filteredBanners.length} ===');
      return filteredBanners;
    } catch (e) {
      print('Bannerlarni yuklashda xatolik: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    try {
      final response = await client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> result = [];
      for (var row in response) {
        // Fallback robust mapping
        final type = (row['type'] ?? row['media_type'] ?? row['post_type'] ?? 'text').toString().toLowerCase();
        final content = (row['content'] ?? row['text'] ?? row['message'] ?? row['caption'] ?? '').toString();
        final mediaUrl = (row['media_url'] ?? row['url'] ?? row['image_url'] ?? row['video_url'] ?? '').toString();
        
        String timeStr = '';
        String dateStr = '';
        if (row['created_at'] != null) {
          final dt = DateTime.parse(row['created_at'].toString()).toLocal();
          timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        }

        result.add({
          'id': row['id'] ?? 0,
          'type': type.contains('video') ? 'video' : (type.contains('image') || type.contains('photo') || mediaUrl.contains('.jpg') || mediaUrl.contains('.png') || mediaUrl.contains('.jpeg')) ? 'image' : 'text',
          'media_url': mediaUrl,
          'content': content,
          'timestamp': timeStr,
          'date': dateStr,
        });
      }
      return result;
    } catch (e) {
      print('=== ANNOUNCEMENTS FETCH ERROR: $e ===');
      return [];
    }
  }

  // --- ADDRESS METHODS ---

  // Manzillarni yuklash
  static Future<List<Map<String, dynamic>>> getUserAddresses(String userId) async {
    try {
      final response = await client
          .from('user_addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Manzillarni yuklashda xatolik: $e');
      return [];
    }
  }

  // Manzilni saqlash (Add/Update)
  static Future<bool> saveUserAddress(Map<String, dynamic> addressData) async {
    try {
      print('=== Saving Address Data: $addressData ===');
      await client.from('user_addresses').upsert(addressData);
      return true;
    } catch (e) {
      print('!!! Geocoder/Address Error: $e !!!');
      if (e is PostgrestException) {
        print('Postgrest Error: ${e.message}, Hint: ${e.hint}, Code: ${e.code}');
      }
      return false;
    }
  }

  // Manzilni o'chirish
  static Future<bool> deleteUserAddress(String addressId) async {
    try {
      await client.from('user_addresses').delete().eq('id', addressId);
      return true;
    } catch (e) {
      print('Manzilni o\'chirishda xatolik: $e');
      return false;
    }
  }

  // Default manzilni sozlash
  static Future<void> setDefaultAddress(String userId, String addressId) async {
    try {
      // Avval hammasini false qilamiz
      await client
          .from('user_addresses')
          .update({'is_default': false})
          .eq('user_id', userId);
      
      // Tanlanganini true qilamiz
      await client
          .from('user_addresses')
          .update({'is_default': true})
          .eq('id', addressId);
    } catch (e) {
      print('Default manzilni sozlashda xatolik: $e');
    }
  }

  // Faol hududlarni (viloyatlarni) olish
  static Future<List<String>> getActiveRegions() async {
    try {
      final response = await client
          .from('app_settings')
          .select('value')
          .eq('key', 'active_regions')
          .maybeSingle();
      
      if (response == null) {
        print('active_regions topilmadi');
        return [];
      }

      final String value = response['value']?.toString() ?? '';
      if (value.isEmpty) return [];
      
      print('=== ACTIVE REGIONS RAW: $value ===');
      
      // JSON array formatida ["tashkent_city", "jizzakh"]
      try {
        final List<dynamic> decoded = json.decode(value);
        final result = decoded.map((e) => e.toString()).toList();
        print('=== ACTIVE REGIONS PARSED: $result ===');
        return result;
      } catch (e) {
        // Agar oddiy string bo'lsa (comma separated)
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    } catch (e) {
      print('Faol hududlarni yuklashda xatolik: $e');
      return [];
    }
  }

  /// Dastavka sozlamalarini olish
  static Future<Map<String, dynamic>> getDeliveryConfig() async {
    try {
      final response = await client
          .from('app_settings')
          .select('value')
          .eq('key', 'delivery_config')
          .maybeSingle();
      
      if (response == null) {
        return {'mode': 'fixed', 'fixedPrice': 15000, 'tiers': []};
      }

      final String value = response['value']?.toString() ?? '';
      if (value.isEmpty) return {'mode': 'fixed', 'fixedPrice': 15000, 'tiers': []};
      
      return json.decode(value) as Map<String, dynamic>;
    } catch (e) {
      print('Dastavka sozlamalarini yuklashda xatolik: $e');
      return {'mode': 'fixed', 'fixedPrice': 15000, 'tiers': []};
    }
  }
}


