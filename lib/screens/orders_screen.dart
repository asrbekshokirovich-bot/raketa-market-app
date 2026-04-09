import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/localization_provider.dart';
import 'dart:math' as math;

// --- MOCK MODELS ---
class OrderItem {
  final String name;
  final String imageUrl;
  final int qty;
  final double price;
  OrderItem({required this.name, required this.imageUrl, required this.qty, required this.price});
}

class OrderModel {
  final String id;
  final String rawId;
  final String date;
  final String status;
  final int currentStep;
  final double totalAmount;
  final String customerName;
  final String phone;
  final String address;
  final String paymentMethod;
  final List<OrderItem> items;
  final String courierCode;

  OrderModel({
    required this.id, required this.rawId, required this.date, required this.status, required this.currentStep,
    required this.totalAmount, required this.customerName, required this.phone, 
    required this.address, required this.paymentMethod, required this.items,
    required this.courierCode,
  });
}

// --- MAIN SCREEN ---
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _customerPhone;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    _setupRealtime();
  }

  void _setupRealtime() {
    _subscription = Supabase.instance.client
      .channel('public:orders')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (payload) {
          _loadOrders(silent: true);
        }
      ).subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    final info = await SupabaseService.getCustomerInfo();
    final phone = info['phone'];
    
    if (phone != null) {
      _customerPhone = phone;
      final rawOrders = await SupabaseService.fetchOrders(phone);
      
      if (mounted) {
        setState(() {
          _orders = rawOrders.map((raw) {
            final List itemsRaw = raw['order_items'] as List? ?? [];
            
            final String rawOrderNumber = raw['order_number'] ?? "#RM-${raw['id'].toString().substring(0, 5).toUpperCase()}";
            
            return OrderModel(
              id: rawOrderNumber,
              rawId: raw['id'].toString(),
              date: DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(raw['created_at'])),
              status: raw['status'] == 'Pending' ? 'Yangi'
                  : raw['status'] == 'Accepted' ? 'Qabul qilingan'
                  : raw['status'] == 'Picking' ? 'Tayyorlanmoqda'
                  : raw['status'] == 'Packed' ? 'Tayyor'
                  : raw['status'] ?? 'Yangi',
              currentStep: _mapStatusToStep(raw['status']),
              totalAmount: double.tryParse(raw['total_amount'].toString()) ?? 0.0,
              customerName: raw['full_name'] ?? '',
              phone: raw['customer_phone'] ?? '',
              address: raw['address'] ?? '',
              paymentMethod: raw['payment_method'] ?? 'Naqd pul',
              courierCode: raw['courier_code'] ?? 'Kutilyapti',
              items: itemsRaw.map((i) {
                final product = i['product_listings'] ?? i['products'] ?? {};
                return OrderItem(
                  name: product['name'] ?? 'Mahsulot',
                  imageUrl: (product['images'] != null && (product['images'] as List).isNotEmpty)
                      ? (product['images'] as List)[0]
                      : (product['image_url'] ?? ''),
                  qty: i['quantity'] ?? 1,
                  price: double.tryParse(i['price_at_time'].toString()) ?? 0.0,
                );
              }).toList(),
            );
          }).toList();

          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _mapStatusToStep(String? status) {
    if (status == null) return 0;
    final s = status.toLowerCase();
    if (s.contains('yangi') || s == 'pending') return 0;
    if (s.contains('qabul') || s == 'accepted' || s.contains('tayyorlanmoqda') || s == 'picking') return 1;
    if (s == 'packed' || s.contains('tayyor')) return 2;
    if (s.contains('yo\'lda') || s == 'delivering') return 3;
    if (s.contains('yetkazildi') || s == 'delivered') return 4;
    return 0;
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00))),
      );
    }

    final newOrders = _orders.where((o) => o.currentStep < 2).toList();
    final deliveredOrders = _orders.where((o) => o.currentStep >= 2).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          context.watch<LocalizationProvider>().translate('buyurtmalarim'),
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF7A00),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF7A00),
          unselectedLabelColor: Colors.grey[500],
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(text: context.watch<LocalizationProvider>().translate('yangi_tab')),
            Tab(text: context.watch<LocalizationProvider>().translate('yetkazilgan_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(newOrders, isDark),
          _buildOrderList(deliveredOrders, isDark),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders, bool isDark) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadOrders(),
        color: const Color(0xFFFF7A00),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              context.read<LocalizationProvider>().translate('hozircha_buyurtmalar_yoq'),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadOrders(silent: true),
      color: const Color(0xFFFF7A00),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
        final order = orders[index];
        String trKey = 'jarayonda';
        if (order.status == 'Yangi') trKey = 'qabul_kutilmoqda';
        else if (order.status == 'Qabul qilingan') trKey = 'qabul_qilingan';
        else if (order.status == 'Tayyorlanmoqda') trKey = 'tayyorlanmoqda';
        else if (order.status == 'Tayyor' || order.status == 'Yetkazib berilgan') trKey = 'yetkazilgan';

        Color sColor = (trKey == 'qabul_kutilmoqda' || trKey == 'jarayonda') 
            ? const Color(0xFFFF7A00) 
            : (trKey == 'yetkazilgan' ? Colors.green : Colors.blue);

        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order)));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.id, 
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.read<LocalizationProvider>().translate(trKey),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold, 
                          fontSize: 10, 
                          color: sColor
                        )
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(order.date, style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${order.items.length} ${context.read<LocalizationProvider>().translate('mahsulot')}", style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600)),
                    Text("${order.totalAmount.toStringAsFixed(0)} so'm", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFFFF7A00))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }
}

// --- ORDER DETAILS SCREEN ---
class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;
  const OrderDetailsScreen({super.key, required this.order});

  String _t(BuildContext context, String key, String fallback) {
    final tr = context.read<LocalizationProvider>().translate(key);
    return tr == key ? fallback : tr;
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 16),
      child: Text(
        title,
        style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildStepper(BuildContext context, int currentStep, bool isDark, String courierCode) {
    // currentStep: 0=Pending, 1=Picking, 2=Waiting, 3=OnTheWay, 4=Delivered
    return Column(
      children: List.generate(4, (index) {
        bool isCompleted = index < currentStep;
        bool isCurrent = index == currentStep;
        
        // Wait, if currentStep == 3 (OnTheWay), index 2 should be considered completed, and index 3 is current!
        // If currentStep == 4 (Delivered), all 4 are completed!
        if (currentStep == 3 && index == 2) {
          isCompleted = true;
          isCurrent = false;
        } else if (currentStep == 3 && index == 3) {
          isCompleted = false;
          isCurrent = true;
        }
        
        // Match specific rules
        if (currentStep == 4) {
          isCompleted = true;
          isCurrent = false;
        }

        bool isLast = index == 3;
        final activeColor = isCompleted ? Colors.green : const Color(0xFFFF7A00);
        final bool isCardActive = isCompleted || isCurrent;
        
        String stepText = "";
        if (index == 0) {
          stepText = isCompleted ? "Qabul qilingan" : (isCurrent ? "Qabul qilish kutilmoqda" : "Qabul qilinishi kutilmoqda");
        } else if (index == 1) {
          stepText = isCompleted ? "Tayyor" : (isCurrent ? "Tayyorlanmoqda" : "Tayyor");
        } else if (index == 2) {
          if (currentStep < 2) stepText = "Yo'lda";
          else if (currentStep == 2) stepText = "Kuryer kutilmoqda";
          else stepText = "Kuryerga berildi";
        } else if (index == 3) {
          if (currentStep < 3) stepText = "Yetkazildi";
          else if (currentStep == 3) stepText = "Yo'lda";
          else stepText = "Yetkazildi";
        }

        final finalText = _t(context, stepText, stepText);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCardActive ? activeColor.withOpacity(0.15) : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    shape: BoxShape.circle,
                    border: Border.all(color: isCardActive ? activeColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!), width: 1.5),
                  ),
                  child: Center(
                    child: isCompleted 
                        ? Icon(Icons.check_rounded, color: activeColor, size: 16)
                        : (isCurrent ? const ThreeDotsLoading() : const SizedBox()),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCardActive ? activeColor.withOpacity(0.05) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finalText,
                      style: GoogleFonts.montserrat(
                        color: isCardActive ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[400]),
                        fontWeight: isCardActive ? FontWeight.bold : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (index == 2 && isCurrent && courierCode != 'Kutilyapti') ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFDE68A), borderRadius: BorderRadius.circular(6)),
                        child: Text("Kuryer: $courierCode", style: GoogleFonts.montserrat(color: const Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 11)),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          _t(context, 'buyurtma_tafsilotlari', 'Buyurtma tafsilotlari'),
          style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .eq('id', order.rawId),
        builder: (context, snapshot) {
          int step = order.currentStep;
          String liveCourierCode = order.courierCode;
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final rawData = snapshot.data!.first;
            final rawStatus = rawData['status'] as String?;
            final s = (rawStatus ?? "").toLowerCase();
            if (s.contains('yangi') || s == 'pending') step = 0;
            else if (s.contains('qabul') || s == 'accepted' || s.contains('tayyorlanmoqda') || s == 'picking') step = 1;
            else if (s == 'packed' || s == 'waiting' || s.contains('tayyor')) step = 2;
            else if (s.contains('yo\'lda') || s == 'ontheway' || s == 'delivering') step = 3;
            else if (s.contains('yetkazildi') || s == 'delivered') step = 4;

            final cCode = rawData['courier_code']?.toString();
            if (cCode != null && cCode.trim().isNotEmpty) {
              liveCourierCode = cCode;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_t(context, 'buyurtma_raqami', 'Buyurtma raqami'), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(order.id, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_t(context, 'sana', 'Sana:'), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(order.date.split(',')[0], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
                      _buildStepper(context, step, isDark, liveCourierCode),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

            _buildSectionTitle(_t(context, 'mahsulotlar', 'Mahsulotlar'), isDark),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: order.items.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                          child: (item.imageUrl.isNotEmpty)
                              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item.imageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.fastfood, color: Colors.grey[400])))
                              : Icon(Icons.fastfood, color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                              const SizedBox(height: 4),
                              Text("${item.qty} x ${item.price.toStringAsFixed(0)} so'm", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        Text("${(item.qty * item.price).toStringAsFixed(0)} so'm", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionTitle(_t(context, 'yetkazib_berish_tafsilotlari', 'Yetkazib berish tafsilotlari'), isDark),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.person_outline, _t(context, 'mijoz', 'Mijoz:'), order.customerName, isDark),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  _buildDetailRow(Icons.phone_outlined, _t(context, 'telefon', 'Telefon:'), order.phone, isDark),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  _buildDetailRow(Icons.location_on_outlined, _t(context, 'manzil', 'Manzil:'), order.address, isDark),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  _buildDetailRow(Icons.credit_card_outlined, _t(context, 'tolov_turi', "To'lov turi:"), order.paymentMethod, isDark),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (step >= 2)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF7A00).withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t(context, 'kuryer_kodi', "Yetkazish kodi"), style: GoogleFonts.montserrat(color: const Color(0xFFFF7A00), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_t(context, 'kuryer_kodi_info', "Tovarni qabul qilgach ushbu kodni kuryerga ayting"), style: GoogleFonts.montserrat(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.courierCode,
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),

            if (step >= 2)
              const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF7A00).withOpacity(0.3), width: 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFFFF7A00).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_t(context, 'jami_tolov', "Jami to'lov"), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  Text("${order.totalAmount.toStringAsFixed(0)} so'm", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFFFF7A00))),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

// --- WAVY DOTS LOADING ANIMATION ---
class ThreeDotsLoading extends StatefulWidget {
  const ThreeDotsLoading({super.key});

  @override
  State<ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<ThreeDotsLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double delayedValue = (_controller.value * 3 - index).clamp(0.0, 1.0);
            if (delayedValue < 0) delayedValue = 0;
            // Create a simple wave effect (sin curve)
            final double scale = 1.0 + 0.5 * math.sin(delayedValue * math.pi);
            final double opacity = 0.5 + 0.5 * math.sin(delayedValue * math.pi);

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
