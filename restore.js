const fs = require('fs');
const file = 'c:/Users/User/Desktop/Abulfayiz project app/supermarket_app/lib/screens/orders_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

const prefix = `import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

`;

// Find where the old file really started
// The current txt starts with "  int _getStep". But maybe we can just insert the prefix at the top.
// Wait, we need to DELETE the _getStep from the top because it's ALREADY inside OrdersScreenState at the bottom where we put it!
// Let's check where _getStep was put.
// My replace4.js did: txt = txt.substring(0, startIndex) + r3 + "\n\n" + txt.substring(endIndex);
// Since startIndex was 0, it replaced the top with r3. Then appended txt.substring(endIndex).
// The top IS the r3 _getStep.
// Let's just DELETE the top _getStep by finding the first @override!

const firstOverride = txt.indexOf('  @override');
if (firstOverride !== -1) {
    txt = prefix + txt.substring(firstOverride);
    fs.writeFileSync(file, txt, 'utf8');
    console.log("Restored successfully!");
} else {
    console.log("Could not find @override");
}
