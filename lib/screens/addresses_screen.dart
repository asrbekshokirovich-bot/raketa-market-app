import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import '../utils/top_toast.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final List<String> _regions = [
    "Andijon viloyati",
    "Buxoro viloyati",
    "Farg'ona viloyati",
    "Jizzax viloyati",
    "Namangan viloyati",
    "Navoiy viloyati",
    "Qashqadaryo viloyati",
    "Qoraqalpog'iston Respublikasi",
    "Samarqand viloyati",
    "Sirdaryo viloyati",
    "Surxondaryo viloyati",
    "Toshkent viloyati",
    "Toshkent shahri",
    "Xorazm viloyati",
  ];

  String? _selectedRegion;
  
  final _districtController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseController = TextEditingController();

  final List<String> _surxondaryoDistricts = [
    "Angor tumani",
    "Bandixon tumani",
    "Boysun tumani",
    "Denov tumani",
    "Jarqo'rg'on tumani",
    "Muzrabot tumani",
    "Oltinsoy tumani",
    "Qiziriq tumani",
    "Qumqo'rg'on tumani",
    "Sariosiyo tumani",
    "Sherobod tumani",
    "Sho'rchi tumani",
    "Termiz tumani",
    "Termiz shahri",
    "Uzun tumani"
  ];

  void _showDistrictPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.only(top: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text(context.read<LocalizationProvider>().translate('district_select_title'), style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _surxondaryoDistricts.length,
                  itemBuilder: (context, index) {
                    final district = _surxondaryoDistricts[index];
                    final isSelected = _districtController.text == district;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      title: Text(district, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: const Color(0xFFFF7A00)) : null,
                      onTap: () {
                        setState(() {
                          _districtController.text = district;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  void _showRegionPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.only(top: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text(context.read<LocalizationProvider>().translate('region_select_title'), style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _regions.length,
                  itemBuilder: (context, index) {
                    final region = _regions[index];
                    final isSelected = _selectedRegion == region;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      title: Text(region, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: const Color(0xFFFF7A00)) : null,
                      onTap: () {
                        setState(() {
                          _selectedRegion = region;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.w500),
          hintText: hint,
          hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: const Color(0xFFFF7A00)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        title: Text(context.watch<LocalizationProvider>().translate('my_address'), style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Region Selector Card
             Text(context.watch<LocalizationProvider>().translate('your_region'), style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[500])),
             const SizedBox(height: 8),
             InkWell(
               onTap: () => _showRegionPicker(isDark),
               borderRadius: BorderRadius.circular(16),
               child: Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: const Color(0xFFFF7A00).withOpacity(0.3), width: 1.5),
                 ),
                 child: Row(
                   children: [
                     const Icon(Icons.map_rounded, color: Color(0xFFFF7A00)),
                     const SizedBox(width: 16),
                     Expanded(
                       child: Text(
                         _selectedRegion ?? context.watch<LocalizationProvider>().translate('select_region_hint'), 
                         style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: _selectedRegion == null ? Colors.grey : (isDark ? Colors.white : Colors.black87)),
                       ),
                     ),
                     const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                   ],
                 ),
               ),
             ),

             const SizedBox(height: 32),

             // Main Content logic based on selected region
             if (_selectedRegion == null)
               Center(
                 child: Padding(
                   padding: const EdgeInsets.only(top: 40),
                   child: Column(
                     children: [
                       Icon(Icons.location_city_rounded, size: 80, color: Colors.grey[300]),
                       const SizedBox(height: 16),
                       Text(
                         context.watch<LocalizationProvider>().translate('add_address_prompt'),
                         textAlign: TextAlign.center,
                         style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[500]),
                       ),
                     ],
                   ),
                 ),
               )
             else if (_selectedRegion != "Surxondaryo viloyati")
               Center(
                 child: Container(
                   padding: const EdgeInsets.all(24),
                   decoration: BoxDecoration(
                     color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                     borderRadius: BorderRadius.circular(24),
                     border: isDark ? Border.all(color: Colors.redAccent.withOpacity(0.2)) : null,
                     boxShadow: !isDark ? [BoxShadow(color: Colors.redAccent.withOpacity(0.1), blurRadius: 20)] : [],
                   ),
                   child: Column(
                     children: [
                       Container(
                         padding: const EdgeInsets.all(20),
                         decoration: BoxDecoration(
                           color: Colors.redAccent.withOpacity(0.1),
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.location_off_rounded, size: 48, color: Colors.redAccent),
                       ),
                       const SizedBox(height: 24),
                       Text(
                         context.watch<LocalizationProvider>().translate('sorry'),
                         style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                       ),
                       const SizedBox(height: 12),
                       Text(
                         context.watch<LocalizationProvider>().translate('no_service'),
                         textAlign: TextAlign.center,
                         style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[500], height: 1.5),
                       ),
                     ],
                   ),
                 ),
               )
             else ...[
                // Surxondaryo Region Form
                Text(context.watch<LocalizationProvider>().translate('address_details'), style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _showDistrictPicker(isDark),
                  child: AbsorbPointer(
                    child: _buildTextField(_districtController, context.watch<LocalizationProvider>().translate('district_label'), context.watch<LocalizationProvider>().translate('district_hint'), Icons.location_city_rounded, isDark),
                  ),
                ),
                _buildTextField(_streetController, context.watch<LocalizationProvider>().translate('street_label'), context.watch<LocalizationProvider>().translate('street_hint'), Icons.signpost_rounded, isDark),
                _buildTextField(_houseController, context.watch<LocalizationProvider>().translate('house_label'), context.watch<LocalizationProvider>().translate('house_hint'), Icons.home_rounded, isDark),
                
                const SizedBox(height: 16),
                
                // Map Picker Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFFF7A00), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      TopToast.show(context, context.read<LocalizationProvider>().translate('map_open_warning'), color: const Color(0xFFFF7A00), icon: Icons.map_rounded);
                    },
                    icon: const Icon(Icons.pin_drop_rounded, color: Color(0xFFFF7A00)),
                    label: Text(context.watch<LocalizationProvider>().translate('pick_map'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFFFF7A00), fontSize: 16)),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (_districtController.text.isEmpty || _streetController.text.isEmpty) {
                         TopToast.show(context, context.read<LocalizationProvider>().translate('fill_all'), color: Colors.redAccent, icon: Icons.warning_rounded);
                         return;
                      }
                      TopToast.show(context, context.read<LocalizationProvider>().translate('address_saved'), color: Colors.green, icon: Icons.check_circle_rounded);
                      Navigator.pop(context);
                    },
                    child: Text(context.watch<LocalizationProvider>().translate('save_button'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  ),
                ),
             ],
          ]
        ),
      ),
    );
  }
}
