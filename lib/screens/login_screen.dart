import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/localization_provider.dart';
import '../widgets/top_notification.dart';
import 'sms_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoginMode = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.watch<LocalizationProvider>().translate('login_title'),
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isLoginMode 
                  ? context.watch<LocalizationProvider>().translate('login_desc_phone')
                  : context.watch<LocalizationProvider>().translate('login_desc_full'),
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              if (!_isLoginMode) ...[
                TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: context.watch<LocalizationProvider>().translate('login_name_label'),
                    labelStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: context.watch<LocalizationProvider>().translate('login_phone_label'),
                  labelStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                  prefixText: '+998 ',
                  prefixStyle: GoogleFonts.montserrat(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final String phone = _phoneController.text.trim();
                    final String name = _nameController.text.trim();

                    if (!_isLoginMode && name.isEmpty) {
                      TopNotification.show(context, context.read<LocalizationProvider>().translate('please_enter_name'), isError: true);
                      return;
                    }
                    if (phone.length < 9) {
                      TopNotification.show(context, context.read<LocalizationProvider>().translate('please_enter_phone_full'), isError: true);
                      return;
                    }
                    
                    // Bazadan tekshirish
                    final auth = context.read<AuthProvider>();
                    final bool exists = await auth.checkUserExists(phone);

                    if (!_isLoginMode && exists) {
                      TopNotification.show(context, context.read<LocalizationProvider>().translate('phone_exists_error'), isError: true);
                      return;
                    }

                    if (_isLoginMode && !exists) {
                      TopNotification.show(context, context.read<LocalizationProvider>().translate('phone_not_exists_error'), isError: true);
                      return;
                    }
                    
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SMSScreen(
                            phone: phone,
                            fullName: _isLoginMode ? null : name,
                          ),
                        ),
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
                    context.watch<LocalizationProvider>().translate('get_code_button'),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  child: Text(
                    _isLoginMode 
                        ? context.watch<LocalizationProvider>().translate("create_new_account") 
                        : context.watch<LocalizationProvider>().translate("already_in_system"),
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF7A00),
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
}
