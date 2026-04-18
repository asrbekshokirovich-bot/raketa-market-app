import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/top_notification.dart';
import '../services/supabase_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _dobController;
  late TextEditingController _emailController;
  late TextEditingController _phoneEditController;
  
  String _phone = "+998 -- --- -- --";
  String _gender = "Erkak";

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    
    // Ism va familiyani ajratish (agar birga bo'lsa)
    String fullName = user?['full_name'] ?? "";
    List<String> parts = fullName.split(' ');
    String name = parts.isNotEmpty ? parts[0] : "";
    String surname = parts.length > 1 ? parts.sublist(1).join(' ') : "";

    _nameController = TextEditingController(text: name);
    _surnameController = TextEditingController(text: surname);
    _dobController = TextEditingController(text: user?['dob'] ?? "");
    _emailController = TextEditingController(text: user?['email'] ?? "");
    
    _phone = user?['phone'] ?? "+998 -- --- -- --";
    _phoneEditController = TextEditingController(text: _phone);
    _gender = user?['gender'] ?? "Erkak";
  }

  Widget _buildPhoneField(bool isDark) {
    bool hasPhoneChanged = _phoneEditController.text != _phone;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _phoneEditController,
        keyboardType: TextInputType.phone,
        maxLength: 17,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
        ],
        onChanged: (val) => setState(() {}),
        style: GoogleFonts.montserrat(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          counterText: "",
          labelText: context.watch<LocalizationProvider>().translate('phone_label'),
          labelStyle: GoogleFonts.montserrat(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!, 
              width: 1.5
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: hasPhoneChanged ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close_rounded, color: Colors.grey[500], size: 20),
                onPressed: () {
                  setState(() {
                    _phoneEditController.text = _phone;
                    FocusScope.of(context).unfocus();
                  });
                },
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: InkWell(
                  onTap: () {
                    _showSmsVerification();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.watch<LocalizationProvider>().translate('verify_btn'),
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFFFF7A00),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
            ],
          ) : null,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label, 
    required String hint,
    required TextEditingController controller, 
    required bool isDark,
    TextInputType type = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: type,
        style: GoogleFonts.montserrat(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
          labelStyle: GoogleFonts.montserrat(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!, 
              width: 1.5
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  void _showDatePicker() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 7300)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: const ColorScheme.light(
               primary: Color(0xFFFF7A00),
               onPrimary: Colors.white,
               onSurface: Colors.black,
             )
           ),
           child: child!,
         );
      }
    );
    if(picked != null) {
       setState(() {
         _dobController.text = "${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}";
       });
    }
  }

  void _showSmsVerification() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 32, left: 24, right: 24
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.watch<LocalizationProvider>().translate('confirm_number'),
              style: GoogleFonts.montserrat(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              )
            ),
            const SizedBox(height: 12),
            Text(
              context.watch<LocalizationProvider>().translate('enter_sms'),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500,
              )
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => Container(
                width: 60, height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: index == 0 ? const Color(0xFFFF7A00) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), width: 1.5)
                ),
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(counterText: "", border: InputBorder.none),
                  onChanged: (val) {
                    if (val.isNotEmpty && index < 3) FocusScope.of(context).nextFocus();
                  },
                ),
              )),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  TopNotification.show(context, context.read<LocalizationProvider>().translate('data_saved'));
                },
                child: Text(context.watch<LocalizationProvider>().translate('verify_btn'), style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountAlert() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.read<LocalizationProvider>().translate('del_acc_title'),
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
            context.read<LocalizationProvider>().translate('del_acc_desc'),
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.read<LocalizationProvider>().translate('bekor_qilish'), 
                style: GoogleFonts.montserrat(
                  color: isDark ? Colors.white : Colors.black87, 
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                )
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
                TopNotification.show(context, context.read<LocalizationProvider>().translate('acc_deleted'), isError: true);
              },
              child: Text(
                context.read<LocalizationProvider>().translate('del_acc_btn'), 
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
              ),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          context.watch<LocalizationProvider>().translate('personal_info'),
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildTextField(label: context.watch<LocalizationProvider>().translate('name_label'), hint: context.watch<LocalizationProvider>().translate('name_hint'), controller: _nameController, isDark: isDark),
                  _buildTextField(label: context.watch<LocalizationProvider>().translate('surname_label'), hint: context.watch<LocalizationProvider>().translate('surname_hint'), controller: _surnameController, isDark: isDark),
                  _buildTextField(
                    label: context.watch<LocalizationProvider>().translate('dob_label'), hint: "KK.OO.YYYY", controller: _dobController, isDark: isDark, 
                    readOnly: true, onTap: _showDatePicker,
                    suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFFFF7A00))
                  ),
                  
                  // Gender Toggle
                  Container(
                    margin: const EdgeInsets.only(bottom: 24, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.watch<LocalizationProvider>().translate('gender_label'), style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildGenderBtn("Erkak", isDark)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildGenderBtn("Ayol", isDark)),
                          ],
                        )
                      ],
                    ),
                  ),

                  // Editable Phone Field
                  _buildPhoneField(isDark),

                  _buildTextField(label: context.watch<LocalizationProvider>().translate('email_label'), hint: context.watch<LocalizationProvider>().translate('email_hint'), controller: _emailController, isDark: isDark, type: TextInputType.emailAddress),
                  
                  const SizedBox(height: 16),
                  
                  // Delete Account TextButton
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _showDeleteAccountAlert,
                      icon: const Icon(Icons.person_off_rounded, size: 20),
                      label: Text(
                        context.watch<LocalizationProvider>().translate('del_acc'),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final String fullName = "${_nameController.text} ${_surnameController.text}".trim();
                    
                    try {
                      await SupabaseService.client
                          .from('app_users')
                          .update({
                            'full_name': fullName,
                            'email': _emailController.text,
                            // Keyinchalik dob va gender ustunlarini ham qo'shishingiz mumkin
                          })
                          .eq('id', auth.userProfile!['id']);
                      
                      await auth.refreshProfile(auth.userProfile!['phone']);
                      
                      if (mounted) {
                        Navigator.pop(context);
                        TopNotification.show(context, context.read<LocalizationProvider>().translate('data_saved'));
                      }
                    } catch (e) {
                      TopNotification.show(context, "Xatolik: $e", isError: true);
                    }
                  },
                  child: Text(context.watch<LocalizationProvider>().translate('save_button'), style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGenderBtn(String type, bool isDark) {
    bool isSelected = _gender == type;
    String displayTitle = type == "Erkak" ? context.watch<LocalizationProvider>().translate('male') : context.watch<LocalizationProvider>().translate('female');
    return InkWell(
      onTap: () => setState(() => _gender = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF7A00).withOpacity(0.1) : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9FAFB)),
          border: Border.all(color: isSelected ? const Color(0xFFFF7A00) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(displayTitle, style: GoogleFonts.montserrat(
            color: isSelected ? const Color(0xFFFF7A00) : (isDark ? Colors.white : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14
          )),
        ),
      ),
    );
  }
}
