import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> get _onboardingData => [
    {
      "title_key": "onboarding_title_1",
      "description_key": "onboarding_desc_1",
    },
    {
      "title_key": "onboarding_title_2",
      "description_key": "onboarding_desc_2",
    },
    {
      "title_key": "onboarding_title_3",
      "description_key": "onboarding_desc_3",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutBack,
            top: _currentPage == 0 ? 60 : _currentPage == 1 ? -20 : 120,
            right: _currentPage == 0 ? 20 : _currentPage == 1 ? 80 : -40,
            child: Transform.rotate(
              angle: _currentPage * 0.5,
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 130,
                color: const Color(0xFFFF7A00).withOpacity(0.06),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutBack,
            bottom: _currentPage == 0 ? 150 : _currentPage == 1 ? 80 : 50,
            left: _currentPage == 0 ? -30 : _currentPage == 1 ? 40 : 100,
            child: Transform.rotate(
              angle: -_currentPage * 0.4,
              child: Icon(
                Icons.local_shipping_outlined,
                size: 150,
                color: const Color(0xFFFF7A00).withOpacity(0.05),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutBack,
            top: _currentPage == 0 ? 350 : _currentPage == 1 ? 450 : 100,
            left: _currentPage == 0 ? 250 : _currentPage == 1 ? -40 : 20,
            child: Transform.rotate(
              angle: _currentPage * 0.3,
              child: Icon(
                Icons.discount_outlined,
                size: 110,
                color: const Color(0xFFFF7A00).withOpacity(0.07),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutBack,
            bottom: _currentPage == 0 ? -50 : _currentPage == 1 ? 300 : -20,
            right: _currentPage == 0 ? 120 : _currentPage == 1 ? -30 : 200,
            child: Transform.rotate(
              angle: _currentPage * 0.6,
              child: Icon(
                Icons.fastfood_outlined,
                size: 100,
                color: const Color(0xFFFF7A00).withOpacity(0.04),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() {
                    _currentPage = value;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  IconData iconData = Icons.shopping_basket;
                  if (index == 1) iconData = Icons.delivery_dining;
                  if (index == 2) iconData = Icons.percent;

                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            size: 90,
                            color: const Color(0xFFFF7A00),
                          ),
                        ),
                        const SizedBox(height: 40),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.watch<LocalizationProvider>().translate(_onboardingData[index]["title_key"]!),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: GoogleFonts.montserrat(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.watch<LocalizationProvider>().translate(_onboardingData[index]["description_key"]!),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingData.length,
                (index) => buildDot(index, context),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _onboardingData.length - 1) {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 600),
                          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            var begin = const Offset(0.0, 0.05);
                            var end = Offset.zero;
                            var curve = Curves.easeOutCubic;

                            var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                            var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

                            return FadeTransition(
                              opacity: animation.drive(fadeTween),
                              child: SlideTransition(
                                position: animation.drive(slideTween),
                                child: child,
                              ),
                            );
                          },
                        ),
                      );
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _onboardingData.length - 1
                        ? context.watch<LocalizationProvider>().translate("onboarding_start")
                        : context.watch<LocalizationProvider>().translate("onboarding_next"),
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ],
  ),
);
  }

  Widget buildDot(int index, BuildContext context) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        height: 10,
        width: _currentPage == index ? 25 : 10,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _currentPage == index
              ? const Color(0xFFFF7A00)
              : Colors.grey[300],
        ),
      ),
    );
  }
}
