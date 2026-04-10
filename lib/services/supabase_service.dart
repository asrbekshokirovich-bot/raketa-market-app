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
}
