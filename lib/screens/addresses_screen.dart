import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import '../providers/address_provider.dart';
import 'add_edit_address_screen.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressProvider = context.watch<AddressProvider>();
    final l10n = context.read<LocalizationProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(l10n.translate('my_address'), style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        elevation: 0,
      ),
      body: addressProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00)))
          : addressProvider.addresses.isEmpty
              ? _buildEmptyState(context, isDark, l10n)
              : _buildAddressList(context, addressProvider, isDark, l10n),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditAddressScreen()));
        },
        backgroundColor: const Color(0xFFFF7A00),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text(l10n.translate('add_new_address'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, LocalizationProvider l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFFF7A00).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.location_off_rounded, size: 80, color: const Color(0xFFFF7A00).withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(l10n.translate('no_addresses_yet'), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressList(BuildContext context, AddressProvider provider, bool isDark, LocalizationProvider l10n) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.addresses.length,
      itemBuilder: (context, index) {
        final address = provider.addresses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: address.isDefault ? Border.all(color: const Color(0xFFFF7A00), width: 1.5) : null,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditAddressScreen(address: address)));
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFF7A00).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_getAddressIcon(address.name), color: const Color(0xFFFF7A00)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(address.name, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                              const SizedBox(width: 8),
                              if (address.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFFF7A00), borderRadius: BorderRadius.circular(6)),
                                  child: Text(l10n.translate('default_label'), style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAddressLine(l10n.translate('region_label'), address.region, isDark),
                              _buildAddressLine(l10n.translate('district_label'), address.district, isDark),
                              _buildAddressLine(l10n.translate('street_label'), address.street, isDark),
                              if (address.house != null && address.house!.isNotEmpty)
                                _buildAddressLine(l10n.translate('house_label'), address.house!, isDark),
                              const SizedBox(height: 4),
                              _buildAddressLine(
                                l10n.translate('coordinates'),
                                "${(address.lat ?? 0.0).toStringAsFixed(6)}, ${(address.lng ?? 0.0).toStringAsFixed(6)}",
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditAddressScreen(address: address)));
                        } else if (value == 'delete') {
                          final confirm = await _showDeleteConfirm(context, isDark, l10n);
                          if (confirm == true) {
                            await provider.deleteAddress(address.id);
                          }
                        } else if (value == 'default') {
                          await provider.setDefaultAddress(address.id);
                        }
                      },
                      itemBuilder: (context) => [
                        if (!address.isDefault)
                          PopupMenuItem(
                            value: 'default',
                            child: Row(
                              children: [
                                Icon(Icons.star_border_rounded, color: Theme.of(context).primaryColor, size: 20),
                                const SizedBox(width: 10),
                                Text(l10n.translate('set_as_default'), style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_road_rounded, color: Colors.blue, size: 20),
                              const SizedBox(width: 10),
                              Text(l10n.translate('malumot'), style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                l10n.translate('del_acc_btn'),
                                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddressLine(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAddressIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('uy') || t.contains('дом') || t.contains('home')) return Icons.home_rounded;
    if (t.contains('ish') || t.contains('rabota') || t.contains('work') || t.contains('ofis')) return Icons.work_rounded;
    return Icons.location_on_rounded;
  }

  Future<bool?> _showDeleteConfirm(BuildContext context, bool isDark, LocalizationProvider l10n) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(l10n.translate('del_acc_title'), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text(l10n.translate('delete_address_confirm'), style: GoogleFonts.montserrat()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.translate('support_cancel'), style: GoogleFonts.montserrat(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.translate('del_acc_btn'), style: GoogleFonts.montserrat(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

