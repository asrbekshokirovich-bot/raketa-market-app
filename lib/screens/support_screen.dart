import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import '../utils/top_toast.dart';
import '../services/supabase_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Map<String, String> _appSettings = {};

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    final settings = await SupabaseService.getAppSettings();
    if (mounted) {
      setState(() {
        _appSettings = settings;
      });
    }
  }

  void _showLaunchSheet(BuildContext context, bool isDark, String type) {
    // Dynamic values check. You can fallback to default if cloud is empty or key not found
    String desc = '';
    if (type == 'telegram') {
      desc = _appSettings['contact_telegram'] ?? _appSettings['telegram_support'] ?? "@raketamarket_admin";
      if (!desc.startsWith('@') && !desc.contains('t.me/')) desc = '@$desc';
    } else {
      String rawPhone = _appSettings['contact_phone'] ?? _appSettings['phone_support'] ?? "90 123 45 67";
      desc = rawPhone.startsWith('+') ? rawPhone : '+998 $rawPhone';
    }

    final title = type == 'telegram' ? context.read<LocalizationProvider>().translate('via_telegram') : context.read<LocalizationProvider>().translate('via_phone');
    final icon = type == 'telegram' ? Icons.telegram : Icons.phone_rounded;
    final color = type == 'telegram' ? Colors.blue : Colors.green;
    final buttonText = type == 'telegram' ? context.read<LocalizationProvider>().translate('send_msg') : context.read<LocalizationProvider>().translate('via_phone');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 6),
            Text(desc, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[500])),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.read<LocalizationProvider>().translate('support_cancel'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      TopToast.show(context, context.read<LocalizationProvider>().translate('redirecting'), color: const Color(0xFFFF7A00), icon: Icons.open_in_new_rounded);
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(buttonText, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, bool isDark, String title, String subtitle, IconData icon, Color color, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: ListTile(
        onTap: () => _showLaunchSheet(context, isDark, type),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        trailing: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.grey[800] : Colors.grey[100]),
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.chevron_right_rounded, color: Colors.grey[500], size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(context.watch<LocalizationProvider>().translate('support_title'), style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.watch<LocalizationProvider>().translate('support_question'),
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.watch<LocalizationProvider>().translate('support_desc'),
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          _buildListTile(context, isDark, context.watch<LocalizationProvider>().translate('via_telegram'), context.watch<LocalizationProvider>().translate('telegram_desc'), Icons.telegram, Colors.blue, 'telegram'),
          _buildListTile(context, isDark, context.watch<LocalizationProvider>().translate('via_phone'), context.watch<LocalizationProvider>().translate('phone_desc'), Icons.phone_rounded, Colors.green, 'phone'),
        ],
      ),
    );
  }
}
