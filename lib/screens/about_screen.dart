import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(context.watch<LocalizationProvider>().translate('ilova_haqida'), style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // App Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.rocket_launch_rounded, color: Color(0xFFFF7A00), size: 48),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Raketa Market",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${context.watch<LocalizationProvider>().translate('versiya')} 1.0.0",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.watch<LocalizationProvider>().translate('about_desc'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          Text(
            context.watch<LocalizationProvider>().translate('faq_title'),
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // FAQ List
          _buildFaqItem(
            isDark,
            context.watch<LocalizationProvider>().translate('faq_q1'),
            context.watch<LocalizationProvider>().translate('faq_a1'),
          ),
          _buildFaqItem(
            isDark,
            context.watch<LocalizationProvider>().translate('faq_q2'),
            context.watch<LocalizationProvider>().translate('faq_a2'),
          ),
          _buildFaqItem(
            isDark,
            context.watch<LocalizationProvider>().translate('faq_q3'),
            context.watch<LocalizationProvider>().translate('faq_a3'),
          ),
          _buildFaqItem(
            isDark,
            context.watch<LocalizationProvider>().translate('faq_q4'),
            context.watch<LocalizationProvider>().translate('faq_a4'),
          ),
          _buildFaqItem(
            isDark,
            context.watch<LocalizationProvider>().translate('faq_q5'),
            context.watch<LocalizationProvider>().translate('faq_a5'),
          ),
        ],
      )
    );
  }

  Widget _buildFaqItem(bool isDark, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: Colors.grey[500],
          iconColor: const Color(0xFFFF7A00),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Text(
            question,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          children: [
            Text(
              answer,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
