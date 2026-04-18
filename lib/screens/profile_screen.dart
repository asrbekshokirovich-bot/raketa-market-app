import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'profile_edit_screen.dart';
import 'orders_screen.dart';
import 'addresses_screen.dart';
import 'favorites_screen.dart';
// import 'stores_screen.dart';
import 'support_screen.dart';
import 'about_screen.dart';
import 'splash_screen.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/localization_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = "Yuklanmoqda...";
  String _userPhone = "Yuklanmoqda...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    // Endi AuthProvider orqali olinadi, lekin bazadan yangilab qo'yish mumkin
    final auth = context.read<AuthProvider>();
    if (auth.userProfile != null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showLogoutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.read<LocalizationProvider>().translate('tizimdan_chiqish'),
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            context.read<LocalizationProvider>().translate('chiqish_tasdiq'),
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.read<LocalizationProvider>().translate('bekor_qilish'), 
                style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 13)
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                if (mounted) {
                  Navigator.pop(context); 
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (context) => const SplashScreen()),
                    (route) => false,
                  );
                }
              },
              child: Text(context.read<LocalizationProvider>().translate('chiqish'), style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        );
      }
    );
  }

  void _showLanguageSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60, height: 6,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 24),
                Text(context.read<LocalizationProvider>().translate('ilova_tilini_tanlang'), style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 16),
                _buildLangTile("O'zbekcha", isDark, setSheetState),
                _buildLangTile("Русский", isDark, setSheetState),
                _buildLangTile("English", isDark, setSheetState),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildLangTile(String lang, bool isDark, StateSetter setSheetState) {
    final currentCode = context.watch<LocalizationProvider>().currentLanguage;
    final isSelected = (currentCode == 'uz' && lang == "O'zbekcha") || 
                       (currentCode == 'ru' && lang == 'Русский') || 
                       (currentCode == 'en' && lang == 'English');
    return ListTile(
      title: Text(lang, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF7A00)) : null,
      onTap: () {
        context.read<LocalizationProvider>().changeLanguage(
          lang == "O'zbekcha" ? 'uz' : (lang == 'Русский' ? 'ru' : 'en')
        );
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) Navigator.pop(context);
        });
      },
    );
  }

  Widget _buildMenuCard(List<Widget> children, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
    Color? overrideColor,
  }) {
    final color = overrideColor ?? (isDark ? Colors.white : Colors.black87);
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: overrideColor != null 
                    ? overrideColor.withOpacity(0.1) 
                    : const Color(0xFFFF7A00).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: overrideColor ?? const Color(0xFFFF7A00),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            if (trailing != null) trailing
            else Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[500],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.userProfile;
    
    _userName = user?['full_name'] ?? "Foydalanuvchi";
    // Agar raqam formatlashtirilgan bo'lsa (+998 ...), uni to'g'ridan-to'g'ri ko'rsatamiz
    _userPhone = user?['phone'] ?? "Tizimga kirmagan";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.watch<LocalizationProvider>().translate('profil'),
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            margin: const EdgeInsets.only(bottom: 32, top: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A00), Color(0xFFFF9D42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A00).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Abstract decorative patterns
                  Positioned(
                    top: -30,
                    right: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: 20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 80,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // Actual Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ]
                          ),
                          child: const Center(
                            child: Icon(Icons.person_rounded, size: 40, color: Color(0xFFFF7A00)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userPhone,
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
                              );
                            },
                            icon: const Icon(Icons.settings_rounded, color: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Orders and Locations
          _buildMenuCard(
            [
              ValueListenableBuilder<int>(
                valueListenable: newOrdersCountNotifier,
                builder: (context, count, child) {
                  return _buildMenuItem(
                    context: context,
                    icon: Icons.shopping_bag_rounded,
                    title: context.watch<LocalizationProvider>().translate('buyurtmalarim'),
                    isDark: isDark,
                    onTap: () {
                      newOrdersCountNotifier.value = 0;
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersScreen()));
                    },
                    trailing: count > 0 
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                              child: Text('+$count ${context.read<LocalizationProvider>().translate('yangi')}', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded, color: Colors.grey[500]),
                          ],
                        )
                      : null,
                  );
                }
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1),
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.location_on_rounded,
                title: context.watch<LocalizationProvider>().translate('mening_manzilim'),
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddressesScreen())),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1),
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.favorite_rounded,
                title: context.watch<LocalizationProvider>().translate('sevimlilar'),
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen())),
              ),
            ],
            isDark,
          ),

          // Settings
          _buildMenuCard(
            [
              _buildMenuItem(
                context: context,
                icon: Icons.language_rounded,
                title: context.watch<LocalizationProvider>().translate('ilova_tili'),
                isDark: isDark,
                onTap: () => _showLanguageSheet(context, isDark),
                trailing: Row(
                  children: [
                    Text(
                      context.watch<LocalizationProvider>().currentLanguage == 'uz' ? "O'zbekcha" : 
                      (context.watch<LocalizationProvider>().currentLanguage == 'ru' ? 'Русский' : 'English'), 
                      style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w600)
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey[500]),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1),
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.dark_mode_rounded,
                title: context.watch<LocalizationProvider>().translate('tungi_rejim'),
                isDark: isDark,
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) {
                    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                  },
                  activeThumbColor: const Color(0xFFFF7A00),
                ),
              ),
            ],
            isDark,
          ),

          // Support
          _buildMenuCard(
            [
              _buildMenuItem(
                context: context,
                icon: Icons.headset_mic_rounded,
                title: context.watch<LocalizationProvider>().translate('qollab_quvvatlash'),
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen())),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1),
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.info_rounded,
                title: context.watch<LocalizationProvider>().translate('ilova_haqida'),
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen())),
              ),
            ],
            isDark,
          ),
          
          const SizedBox(height: 16),

          // Logout
          _buildMenuCard(
            [
              _buildMenuItem(
                context: context,
                icon: Icons.logout_rounded,
                title: context.watch<LocalizationProvider>().translate('tizimdan_chiqish'),
                isDark: isDark,
                overrideColor: Colors.redAccent,
                onTap: () => _showLogoutDialog(context, isDark),
              ),
            ],
            isDark,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
