import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import 'onboarding_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}
class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalizationProvider>().loadLanguage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/raketa_logo.png', width: 80, height: 80),
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                context.watch<LocalizationProvider>().translate('tilni_tanlang'),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 48),

              // Language options
              _buildLanguageOption(
                code: 'uz',
                title: 'O\'zbekcha',
                subtitle: 'Lotin yozuvida',
                iconText: 'UZ',
              ),
              const SizedBox(height: 16),
              _buildLanguageOption(
                code: 'ru',
                title: 'Русский',
                subtitle: 'На кириллице',
                iconText: 'RU',
              ),
              const SizedBox(height: 16),
              _buildLanguageOption(
                code: 'en',
                title: 'English',
                subtitle: 'In Latin script',
                iconText: 'EN',
              ),

              const SizedBox(height: 32),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to OnboardingScreen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.watch<LocalizationProvider>().translate('davom_etish'),
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({required String code, required String title, required String subtitle, required String iconText}) {
    final localization = context.watch<LocalizationProvider>();
    final bool isSelected = localization.currentLanguage == code;

    return InkWell(
      onTap: () {
        localization.changeLanguage(code);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF4E5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7A00) : Colors.grey.withOpacity(0.3), 
            width: isSelected ? 2.0 : 1.5
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF7A00) : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Text(
                iconText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     title,
                     style: GoogleFonts.montserrat(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: isSelected ? const Color(0xFFFF7A00) : Colors.black87,
                     )
                   ),
                   const SizedBox(height: 4),
                   Text(
                     subtitle,
                     style: GoogleFonts.montserrat(
                       fontSize: 13,
                       fontWeight: FontWeight.w600,
                       color: isSelected ? const Color(0xFFFF9500) : Colors.grey[500],
                     )
                   ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined, 
              color: isSelected ? const Color(0xFFFF7A00) : Colors.grey[300],
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
