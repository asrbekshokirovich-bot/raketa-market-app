import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/supabase_service.dart';
import '../main.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _userProfile != null;

  AuthProvider() {
    _loadSession();
  }

  // Local sessiyani yuklash
  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('current_user');
    if (userJson != null) {
      _userProfile = json.decode(userJson);
      notifyListeners();
      // Ma'lumotlarni bazadan yangilab qo'yamiz (agar o'zgargan bo'lsa)
      if (_userProfile?['phone'] != null) {
        refreshProfile(_userProfile!['phone']);
        _syncActiveOrdersCount();
      }
    } else {
      notifyListeners();
    }
  }

  // Foydalanuvchi bor-yo'qligini tekshirish
  Future<bool> checkUserExists(String phone) async {
    try {
      // 1-usul: Oddiygina qismlarga bo'lib, probellar bilan qidirish (CRM formati uchun: +998 90 123 45 67)
      String formattedPhone = "";
      if (phone.length == 9) {
        formattedPhone = "+998 ${phone.substring(0, 2)} ${phone.substring(2, 5)} ${phone.substring(5, 7)} ${phone.substring(7, 9)}";
      }

      final response = await SupabaseService.client
          .from('app_users')
          .select()
          .or('phone.ilike.%$phone%,phone.eq.$formattedPhone')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Check error: $e');
      return false;
    }
  }

  // Telefon orqali profilni yuklash yoki yaratish
  Future<bool> loginOrRegister({
    required String phone,
    String? fullName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Avval mavjudligini tekshiramiz (Formatlashtirilgan yoki raw raqam bo'yicha)
      String formattedPhone = "";
      if (phone.length == 9) {
        formattedPhone = "+998 ${phone.substring(0, 2)} ${phone.substring(2, 5)} ${phone.substring(5, 7)} ${phone.substring(7, 9)}";
      }

      final response = await SupabaseService.client
          .from('app_users') 
          .select()
          .or('phone.ilike.%$phone%,phone.eq.$formattedPhone') 
          .maybeSingle();

      if (response != null) {
        _userProfile = response;
      } else {
        // 2. Agar yo'q bo'lsa va ism berilgan bo'lsa, yaratamiz
        if (fullName != null) {
          final newUser = {
            'id': const Uuid().v4(), 
            'full_name': fullName,
            'role': 'Mijoz',
            'phone': '+998 $phone', 
            'created_at': DateTime.now().toIso8601String(),
          };
          
          final insertResponse = await SupabaseService.client
              .from('app_users')
              .insert(newUser)
              .select()
              .single();
          
          _userProfile = insertResponse;
        } else {
          _isLoading = false;
        // Global countni yangilash
        newOrdersCountNotifier.value = 0;
    notifyListeners();
          return false;
        }
      }

      // 3. Sessiyani saqlash
      if (_userProfile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', json.encode(_userProfile));
        _syncActiveOrdersCount();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Auth Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Ma'lumotlarni yangilash
  Future<void> refreshProfile(String phone) async {
    try {
      String formattedPhone = "";
      if (phone.length == 9) {
        formattedPhone = "+998 ${phone.substring(0, 2)} ${phone.substring(2, 5)} ${phone.substring(5, 7)} ${phone.substring(7, 9)}";
      }

      final response = await SupabaseService.client
          .from('app_users')
          .select()
          .or('phone.ilike.%$phone%,phone.eq.$formattedPhone')
          .maybeSingle();
      
      if (response != null) {
        _userProfile = response;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', json.encode(_userProfile));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh Error: $e');
    }
  }

  Future<void> _syncActiveOrdersCount() async {
    try {
      final orders = await SupabaseService.fetchOrders('');
      int activeCount = 0;
      for (var raw in orders) {
        final String? status = raw['status'];
        if (status == null) continue;
        final s = status.toLowerCase();
        int step = 0;
        if (s.contains('bekor') || s == 'cancelled') {
          step = -1;
        } else if (s.contains('yangi') || s == 'pending' || s == 'waiting') {
          step = 0;
        } else if (s.contains('qabul') || s == 'accepted' || s.contains('tayyorlanmoqda') || s == 'picking') {
          step = 1;
        } else if (s == 'packed' || s.contains('tayyor') || s == 'ready') {
          step = 2;
        } else if (s.contains('yo\'lda') || s == 'delivering' || s == 'ontheway') {
          step = 3;
        } else if (s.contains('yetkazildi') || s == 'delivered') {
          step = 4;
        }
        
        if (step >= 0 && step < 4) activeCount++;
      }
      newOrdersCountNotifier.value = activeCount;
    } catch(e) {
      debugPrint('Sync orders count error: $e');
    }
  }

  // Tizimdan chiqish
  Future<void> signOut() async {
    _userProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    newOrdersCountNotifier.value = 0;
    notifyListeners();
  }
}
