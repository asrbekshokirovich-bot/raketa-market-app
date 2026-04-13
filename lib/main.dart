import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_preview/device_preview.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/localization_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/address_provider.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<int> newOrdersCountNotifier = ValueNotifier(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase'ni ishga tushiramiz
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialize error: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  themeNotifier.addListener(() {
    prefs.setBool('is_dark', themeNotifier.value == ThemeMode.dark);
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationProvider()..loadLanguage()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (_) => FavoritesProvider(),
          update: (_, auth, favorites) {
            final resultFavorites = favorites ?? FavoritesProvider();
            resultFavorites.updateUserId(auth.userProfile?['id']?.toString());
            return resultFavorites;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) => CartProvider(),
          update: (_, auth, cart) {
            final resultCart = cart ?? CartProvider();
            resultCart.updateUserId(auth.userProfile?['id']?.toString());
            return resultCart;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AddressProvider>(
          create: (_) => AddressProvider(),
          update: (_, auth, address) {
            final resultAddress = address ?? AddressProvider();
            resultAddress.updateUserId(auth.userProfile?['id']?.toString());
            return resultAddress;
          },
        ),
      ],
      child: DevicePreview(
        enabled: true,
        builder: (context) => const SupermarketApp(),
      ),
    ),
  );
}

class SupermarketApp extends StatelessWidget {
  const SupermarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          title: 'Raketa Market App',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.unknown},
          ),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7A00)),
            scaffoldBackgroundColor: const Color(0xFFF3F4F6),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF7A00),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
