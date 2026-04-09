import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'language_selection_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconFadeAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Silliq suvdek to'qnashish animatsiyasi 2.5 sekund (juda tez va silliq)
    _controller = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 2500)
    );

    // 1-qadam: Oq fon xuddi suv sepgandek (elastic) kengayib chiqishi (0.0 dan 0.5 gacha)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut))
    );

    // 2-qadam: Ichidagi logotip asta tiniqlashishi (0.4 dan 0.8 gacha)
    _iconFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.8, curve: Curves.easeIn))
    );

    // 3-qadam: Yozuv asta xiralikdan tiniqlashishi (0.4 dan 0.8 gacha)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.8, curve: Curves.easeIn))
    );

    // 4-qadam: Yozuv pastdan tepaga ko'tarilib kelishi (0.4 dan 0.8 gacha)
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic))
    );

    _controller.forward();

    // Animatsiya tugagach (jami 4.5 soniya)
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
                auth.isLoggedIn ? const MainScreen() : const LanguageSelectionScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF7A00),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 15,
                    )
                  ]
                ),
                child: FadeTransition(
                  opacity: _iconFadeAnimation,
                  child: Image.asset('assets/images/raketa_logo.png', width: 100, height: 100),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Text(
                  'Raketa Market',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700, // Ozgina ingichkaroq qilingan
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            // Kesh uchun yashirin matn (miltillashni oldini olish uchun barcha qalinliklarni yuklash)
            Opacity(
              opacity: 0.0,
              child: Column(
                children: [
                  Text('p', style: GoogleFonts.montserrat(fontWeight: FontWeight.w400)),
                  Text('p', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                  Text('p', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                  Text('p', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

