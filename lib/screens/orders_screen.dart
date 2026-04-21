import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/localization_provider.dart';
import '../utils/top_toast.dart';
import 'dart:math' as math;

String _fC(dynamic amount) {
  if (amount == null) return "0";
  double val = 0;
  if (amount is String) {
    val = double.tryParse(amount.replaceAll(' ', '')) ?? 0.0;
  } else if (amount is num) {
    val = amount.toDouble();
  }
  return NumberFormat('#,###').format(val).replaceAll(',', ' ');
}

// --- MOCK MODELS ---
class OrderItem {
  final String name;
  final String imageUrl;
  final int qty;
  final double price;
  final bool isDiscounted;
  OrderItem({required this.name, required this.imageUrl, required this.qty, required this.price, this.isDiscounted = false});
}

int mapStatusToStep(String? status) {
  if (status == null) return 0;
  final s = status.toLowerCase();
  if (s.contains('yangi') || s == 'pending' || s == 'waiting') return 0;
  if (s.contains('qabul') || s == 'accepted' || s.contains('tayyorlanmoqda') || s == 'picking') return 1;
  if (s == 'packed' || s.contains('tayyor') || s == 'ready') return 2;
  if (s.contains('yo\'lda') || s == 'delivering' || s == 'ontheway') return 3;
  if (s.contains('yetkazildi') || s == 'delivered') return 4;
  return 0;
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
  final double deliveryFee;
  final double discountAmount;
  final String coordinates;

  OrderModel({
    required this.id, required this.rawId, required this.date, required this.status, required this.currentStep,
    required this.totalAmount, required this.customerName, required this.phone, 
    required this.address, required this.paymentMethod, required this.items,
    required this.courierCode,
    this.deliveryFee = 0.0,
    this.discountAmount = 0.0,
    this.coordinates = '',
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
      .channel('orders_realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (payload) {
          debugPrint('REALTIME UPDATE RECEIVED: ${payload.eventType}');
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
    final rawOrders = await SupabaseService.fetchOrders('');
    
    if (mounted) {
      setState(() {
        _orders = rawOrders.map((raw) {
          final itemsRaw = (raw['order_items'] as List?) ?? [];
          
          final String rawOrderString = (raw['order_number'] ?? "#ID-${raw['id'].toString().substring(0, 5).toUpperCase()}").toString();
          final String rawOrderNumber = rawOrderString.replaceAll('#RM-', '#ID-');
          
          return OrderModel(
            id: rawOrderNumber,
            rawId: (raw['id'] ?? '').toString(),
            date: DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(raw['created_at'] ?? DateTime.now().toIso8601String())),
            status: (raw['status'] == 'Pending' ? 'Yangi'
                : raw['status'] == 'Accepted' ? 'Qabul qilingan'
                : raw['status'] == 'Picking' ? 'Tayyorlanmoqda'
                : raw['status'] == 'Packed' ? 'Tayyor'
                : raw['status'] ?? 'Yangi').toString(),
            currentStep: mapStatusToStep(raw['status']?.toString()),
            totalAmount: double.tryParse((raw['total_amount'] ?? '0').toString()) ?? 0.0,
            customerName: (raw['full_name'] ?? '').toString(),
            phone: (raw['customer_phone'] ?? '').toString(),
            address: (raw['address'] ?? '').toString(),
            paymentMethod: (raw['payment_method'] ?? 'Naqd pul').toString(),
            courierCode: (raw['courier_code'] ?? 'Kutilyapti').toString(),
            deliveryFee: double.tryParse((raw['delivery_fee'] ?? '0').toString()) ?? 0.0,
            discountAmount: double.tryParse((raw['discount_amount'] ?? '0').toString()) ?? 0.0,
            coordinates: (raw['coordinates'] ?? '').toString(),
            items: itemsRaw.map((i) {
              final itemMap = (i as Map?) ?? {};
              final product = (itemMap['product_listings'] ?? itemMap['products'] ?? {}) as Map;
              return OrderItem(
                name: (product['name'] ?? 'Mahsulot').toString(),
                imageUrl: (product['images'] != null && (product['images'] as List).isNotEmpty)
                    ? (product['images'] as List)[0].toString()
                    : (product['image_url'] ?? '').toString(),
                qty: int.tryParse((itemMap['quantity'] ?? '1').toString()) ?? 1,
                price: double.tryParse((itemMap['price_at_time'] ?? '0').toString()) ?? 0.0,
                isDiscounted: (product['discount_percent'] != null && product['discount_percent'].toString() != '0'),
              );
            }).toList(),
          );
        }).toList();

        _isLoading = false;
      });
    }
  }




  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00))),
      );
    }

    final newOrders = _orders.where((o) => o.currentStep < 4).toList();
    final deliveredOrders = _orders.where((o) => o.currentStep >= 4).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFEEEEEE),
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
        if (order.status == 'Yangi') {
          trKey = 'qabul_kutilmoqda';
        } else if (order.status == 'Qabul qilingan') trKey = 'qabul_qilingan';
        else if (order.status == 'Tayyorlanmoqda') trKey = 'tayyorlanmoqda';
        else if (order.status == 'Tayyor' || order.status == 'Yetkazib berilgan') trKey = 'yetkazilgan';

        Color sColor = (trKey == 'yetkazilgan') 
            ? Colors.green 
            : (isDark ? Colors.white : Colors.black87);

        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white : Colors.black87),
                        const SizedBox(width: 6),
                        Text(order.date, style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                
                Builder(
                  builder: (context) {
                    String orderSeq = "";
                    String orderHash = order.id;
                    if (order.id.contains('•')) {
                      final parts = order.id.split('•');
                      orderSeq = parts[0].trim().replaceAll('No-', '');
                      orderHash = parts[1].trim();
                    } else if (order.id.contains('-')) {
                      final parts = order.id.split('-');
                      if (parts.length >= 2 && order.id.startsWith('No')) {
                         orderSeq = parts[1].trim().split(' ').first;
                         orderHash = order.id.substring(order.id.indexOf(orderSeq) + orderSeq.length).trim();
                      }
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (orderSeq.isNotEmpty) _buildInfoRow(_t(context, 'buyurtma_no', "Buyurtma №:"), orderSeq, isDark, valueColor: const Color(0xFFFF7A00), valueSize: 13),
                        if (orderSeq.isNotEmpty) const SizedBox(height: 8),
                        _buildInfoRow(_t(context, 'buyurtma_id_title', "Buyurtma ID:"), orderHash, isDark, valueColor: Colors.grey[600], valueSize: 13),
                      ]
                    );
                  }
                ),
                const SizedBox(height: 8),
                _buildInfoRow(_t(context, 'yuboruvchi', "Yuboruvchi:"), "Raketa Market", isDark),
                const SizedBox(height: 8),
                _buildInfoRow(_t(context, 'mahsulotlar_soni', "Mahsulotlar soni:"), "${order.items.length} ${_t(context, 'ta_dona', "ta")}", isDark),
                const SizedBox(height: 8),
                _buildInfoRow(_t(context, 'oluvchi', "Oluvchi:"), order.customerName, isDark),
                const SizedBox(height: 8),
                _buildInfoRow(_t(context, 'telefon_raqami', "Telefon raqami:"), order.phone, isDark),
                const SizedBox(height: 8),
                _buildInfoRow(_t(context, 'manzil', "Manzil:"), _getPureAddress(order.address), isDark),
                const SizedBox(height: 8),
                if (order.coordinates.isNotEmpty) 
                  _buildInfoRow(_t(context, 'kordinatalar', "Kordinatalar:"), order.coordinates, isDark, valueColor: Colors.blue[600]),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_t(context, 'jami_summa', "Jami summa:"), style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text("${_fC(order.totalAmount)} ${_t(context, 'som', "so'm")}", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFFFF7A00))),
                  ],
                ),

                const SizedBox(height: 16),
                Center(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order)));
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        _t(context, 'mahsulotni_korish', "Mahsulotni ko'rish"),
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFFFF7A00),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFFFF7A00),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
      },
    ),
    );
  }

  String _t(BuildContext context, String key, [String fallback = '']) {
    final tr = context.watch<LocalizationProvider>().translate(key);
    return tr == key && fallback.isNotEmpty ? fallback : tr;
  }


  Widget _buildInfoRow(String title, String value, bool isDark, {Color? valueColor, double valueSize = 13}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            title, 
            style: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)
          ),
        ),
        Expanded(
          child: Text(
            value, 
            style: GoogleFonts.montserrat(
              color: valueColor ?? (isDark ? Colors.white : Colors.black87), 
              fontSize: valueSize, 
              fontWeight: FontWeight.bold
            ), 
            textAlign: TextAlign.left,
          ),
        ),
      ],
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
        final activeColor = isCompleted ? Colors.green : (isDark ? Colors.white : Colors.black87);
        final bool isCardActive = isCompleted || isCurrent;
        
        String stepText = "";
        if (index == 0) {
          stepText = isCompleted ? "Qabul qilingan" : (isCurrent ? "Qabul qilish kutilmoqda" : "Qabul qilinishi kutilmoqda");
        } else if (index == 1) {
          stepText = isCompleted ? "Tayyor" : (isCurrent ? "Tayyorlanmoqda" : "Tayyor");
        } else if (index == 2) {
          if (currentStep < 2) {
            stepText = "Yo'lda";
          } else if (currentStep == 2) stepText = "Kuryer kutilmoqda";
          else stepText = "Kuryerga berildi";
        } else if (index == 3) {
          if (currentStep < 3) {
            stepText = "Yetkazildi";
          } else if (currentStep == 3) stepText = "Yo'lda";
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            step = mapStatusToStep(rawStatus);

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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          step == 4 ? _t(context, 'order_delivered_title', "Buyurtma yetkazildi") : (step == -1 || order.status.toLowerCase().contains("cancel") ? _t(context, 'order_cancelled_title', "Buyurtma bekor qilingan") : _t(context, 'order_process_title', "Buyurtmam qaysi jarayonda:")),
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold, 
                            fontSize: 14, 
                            color: step == 4 ? Colors.green : (step == -1 || order.status.toLowerCase().contains("cancel") ? Colors.red : (isDark ? Colors.white : Colors.black))
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStepper(context, step, isDark, liveCourierCode),
                      
                      if (step < 2) ...[
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        CancelOrderWidget(orderId: order.rawId, isDark: isDark),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_t(context, 'buyurtma_raq_id', "Buyurtma raqami / ID:"), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(order.id, style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_t(context, 'tolov_usuli', "To'lov usuli:"), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(order.paymentMethod.isNotEmpty ? order.paymentMethod : _t(context, 'kuryerga_tolov', "Kuryerga"), style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_t(context, 'sana_va_vaqt', "Sana va vaqt:"), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(order.date, style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t(context, 'manzil', "Manzil:"), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              _getPureAddress(order.address),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (_getCourierNote(order.address).isNotEmpty) ... [
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_t(context, 'kuryerga_izoh', "Kuryerga izoh:"), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                _getCourierNote(order.address),
                                textAlign: TextAlign.right,
                                style: GoogleFonts.montserrat(
                                  color: isDark ? Colors.white : Colors.black87, 
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

            _buildSectionTitle(_t(context, 'mahsulotlar', 'Mahsulotlar'), isDark),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  ListView.separated(
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
                                  if (item.isDiscounted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(_t(context, 'chegirmalik_badge', 'Chegirmalik'), style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  Text(item.name, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text("${item.qty} ${_t(context, 'ta_dona', 'dona')} x ${_fC(item.price)} ${_t(context, 'som', "so'm")}", style: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Text("${_fC(item.qty * item.price)} ${_t(context, 'som', "so'm")}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (ctx) {
                      double itemsSum = 0;
                      for (var i in order.items) { itemsSum += i.price * i.qty; }
                      
                      double dispDelivery = order.deliveryFee;
                      double dispPromo = order.discountAmount;

                      // Fallback for older orders where breakdown wasn't saved
                      if (dispDelivery == 0 && dispPromo == 0) {
                        double diff = order.totalAmount - itemsSum;
                        if (diff > 0) {
                          if (diff < 15000) { // Likely 15000 - promo
                            dispDelivery = 15000;
                            dispPromo = 15000 - diff;
                          } else {
                            dispDelivery = diff;
                          }
                        } else if (diff < 0) {
                          dispPromo = diff.abs();
                        }
                      }
                      
                      return Column(
                        children: [
                          const Divider(height: 1, thickness: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_t(context, 'hisob_kitob', "Hisob-kitob"), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_t(context, 'umumiy_mahsulot_narxi', "Umumiy mahsulot narxi:"), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text("${_fC(itemsSum)} ${_t(context, 'som', "so'm")}", style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_t(context, 'yetkazib_berish_title', "Yetkazib berish:"), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                      Text(dispDelivery > 0 ? "${_fC(dispDelivery)} ${_t(context, 'som', "so'm")}" : "${_t(context, 'bepul', 'Bepul')} (0 ${_t(context, 'som', "so'm")})", style: GoogleFonts.montserrat(color: dispDelivery > 0 ? (isDark ? Colors.white : Colors.black87) : Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_t(context, 'promo_kod_chegirma', "Promo kod (Chegirma):"), style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                      Text(dispPromo > 0 ? "- ${_fC(dispPromo)} ${_t(context, 'som', "so'm")}" : _t(context, 'yoq', "Yo'q"), style: GoogleFonts.montserrat(color: dispPromo > 0 ? Colors.green : Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_t(context, 'jami_summa', "Jami summa:"), style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                                    Text("${_fC(order.totalAmount)} ${_t(context, 'som', "so'm")}", style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),

            if (step >= 2)
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


            const SizedBox(height: 40),
          ],
        ),
          );
        },
      ),
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

class CancelOrderWidget extends StatefulWidget {
  final String orderId;
  final bool isDark;

  const CancelOrderWidget({super.key, required this.orderId, required this.isDark});

  @override
  State<CancelOrderWidget> createState() => _CancelOrderWidgetState();
}

class _CancelOrderWidgetState extends State<CancelOrderWidget> {
  bool _showInfo = false;
  bool _isCancelling = false;

  void _cancelOrder() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                "Bekor qilish",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: widget.isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
        content: Text(
          "Biz buyurtmangiz ustida mehnat qilyapmiz, rostdan ham buyurtmani bekor qilasizmi?",
          style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Yo'q", style: GoogleFonts.montserrat(color: widget.isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B4B),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Ha", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await Supabase.instance.client.from('orders').update({'status': 'Cancelled'}).eq('id', widget.orderId);
      if (mounted) TopToast.show(context, _tr('order_cancelled', "Buyurtma bekor qilindi"), color: Colors.green);
    } catch(e) {
      if (mounted) TopToast.show(context, "${_tr('error', 'Xatolik')}: $e", color: Colors.red, icon: Icons.error_outline);
    }
    if (mounted) setState(() => _isCancelling = false);
  }

  String _tr(String key, String fallback) {
    final t = context.read<LocalizationProvider>().translate(key);
    return (t == key || t.isEmpty) ? fallback : t;
  }

  String _tw(String key, String fallback) {
    final t = context.watch<LocalizationProvider>().translate(key);
    return (t == key || t.isEmpty) ? fallback : t;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => setState(() => _showInfo = !_showInfo),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.grey[800] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline_rounded, color: Colors.grey[600], size: 20),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isCancelling ? null : _cancelOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
              child: _isCancelling 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                : Text(_tw('cancel_order_btn', "Buyurtmani bekor qilish"), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        if (_showInfo)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _tw('cancel_warning_desc', "Siz buyurtmani qabul qilinishidan oldin va tayyorlanish jarayonigacha bemalol bekor qilishingiz mumkin. Ammo buyurtma 'Tayyor' bo'lib kuryerga o'tgandan so'ng bekor qilib bo'lmaydi!"),
              style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 12, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

String _getPureAddress(String address) {
  // Avval kuryer izohini (newline dan keyingi qismni) olib tashlaymiz
  String cleanAddr = address.split('\n')[0].trim();
  
  int koordIndex = cleanAddr.indexOf('(Koord:');
  if (koordIndex != -1) {
    int closeParenIndex = cleanAddr.indexOf(')', koordIndex);
    if (closeParenIndex != -1) {
      return cleanAddr.substring(0, closeParenIndex + 1).trim();
    }
  }
  return cleanAddr;
}

String _getCourierNote(String address) {
  // Newline dan keyingi qism kuryer tavsifi deb hisoblanadi
  final parts = address.split('\n');
  if (parts.length > 1) {
    return parts.sublist(1).join('\n').trim();
  }
  
  // Eskicha format bo'lsa (Koord dan keyingi qism)
  int koordIndex = address.indexOf('(Koord:');
  if (koordIndex != -1) {
    int closeParenIndex = address.indexOf(')', koordIndex);
    if (closeParenIndex != -1 && closeParenIndex + 1 < address.length) {
      return address.substring(closeParenIndex + 1).trim();
    }
  }
  return '';
}
