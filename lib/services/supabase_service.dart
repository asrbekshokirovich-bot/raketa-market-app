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
      
      print('=== Fetched App Settings ===');
      print(settings);
      
      return settings;
    } catch (e) {
      print('Xatolik: app_settings jadvalini tortishda muammo - $e');
      return {};
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
        'items_count': items.length,
        'total_amount': totalAmount,
        'status': 'Pending', // CRM qabul qilishi uchun Pending ga o'zgartirildi
        'courier_code': courierCodeGenerated,
      }).select().single();

      final orderId = orderResponse['id'];

      // 2. Order Items jadvaliga kiritish
      final List<Map<String, dynamic>> itemsToInsert = items.map((item) {
        return {
          'order_id': orderId,
          'product_id': item['product_id'],
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
          .select('*, order_items(*, product_listings(*))')
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
          .select('*, product_listings(*)')
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(response);
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

}

