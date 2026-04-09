const fs = require('fs');

const path = 'lib/screens/orders_screen.dart';
let code = fs.readFileSync(path, 'utf8');

// 1. Remove const from OrderDetailsScreen
code = code.replace(
  'const OrderDetailsScreen({super.key, required this.order});',
  'OrderDetailsScreen({super.key, required this.order});'
);

// 2. Fix the line 481 "\n\n" error that restore.js brought back
code = code.replace(
  '  }\\n\\n  @override',
  '  }\n\n  @override'
);

// 3. Fix _mapStatusToStep in OrdersScreen
const oldMapStatus = `  int _mapStatusToStep(String? status) {
    if (status == null) return 0;
    final s = status.toLowerCase();
    if (s.contains('yangi') || s == 'pending') return 0;
    if (s.contains('qabul') || s == 'accepted') return 1;
    if (s.contains('tayyorlanmoqda') || s == 'picking') return 2;
    if (s.contains('tayyor') || s.contains('yo\\'lda') || s == 'packed' || s == 'delivered') return 3;
    return 0;
  }`;
const newMapStatus = `  int _mapStatusToStep(String? status) {
    if (status == null) return 0;
    final s = status.toLowerCase();
    if (s.contains('yangi') || s == 'pending') return 0;
    if (s.contains('qabul') || s == 'accepted' || s.contains('tayyorlanmoqda') || s == 'picking') return 1;
    if (s == 'packed' || s.contains('tayyor')) return 2;
    if (s.contains('yo\\'lda') || s == 'delivering') return 3;
    if (s.contains('yetkazildi') || s == 'delivered') return 4;
    return 0;
  }`;
code = code.replace(oldMapStatus, newMapStatus);

// 4. Replace pendingTexts
const oldPending = `    final pendingTexts = [
      "Qabul qilish kutilmoqda", 
      "Tayyorlash kutilmoqda", 
      "Kuryer kutilmoqda", 
      "Qabul qilinishi kutilmoqda"
    ];`;
const newPending = `    final pendingTexts = [
      "Qabul qilish kutilmoqda", 
      "Tayyorlanmoqda", 
      "Kuryer kutilmoqda", 
      "Qabul qilinishi kutilmoqda"
    ];`;
code = code.replace(oldPending, newPending);

// 5. Replace completedTexts
const oldComp = `    final completedTexts = [
      "Qabul qilingan", 
      "Tayyorlanmoqda", 
      "Yo'lda", 
      "Yetkazildi"
    ];`;
const newComp = `    final completedTexts = [
      "Qabul qilingan", 
      "Tayyor", 
      "Yo'lda", 
      "Yetkazildi"
    ];`;
code = code.replace(oldComp, newComp);

// 6. Fix isStatusPicking logic to just logical standard
const oldGen = `          final sName = status.toLowerCase();
          final isStatusPicking = sName.contains('tayyorlanmoqda') || sName == 'picking';
          
          bool isCompleted = index < currentStep;
          bool isCurrent = index == currentStep;
          
          if (isStatusPicking && index == 1) {
            isCompleted = true;
            isCurrent = false;
          }

          final isLast = index == 3;
          final activeColor = isCompleted ? Colors.green : const Color(0xFFFF7A00);`;
const newGen = `          bool isCompleted = index < currentStep;
          bool isCurrent = index == currentStep;
          final isLast = index == 3;
          final activeColor = isCompleted ? Colors.green : const Color(0xFFFF7A00);`;
code = code.replace(oldGen, newGen);

// Just in case oldGen wasn't matched because restore.js had the older logic:
const olderGen = `          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          final isFuture = index > currentStep;
          final isLast = index == 3;
          final isSpecialPicking = isCurrent && index == 1 && (status.toLowerCase().contains('tayyorlanmoqda') || status.toLowerCase() == 'picking');

          final activeColor = isCompleted ? Colors.green : (isSpecialPicking ? Colors.green : const Color(0xFFFF7A00));`;
code = code.replace(olderGen, newGen);

const oldTextCond = `          String stepText = "";
          if (isCompleted) stepText = completedTexts[index];
          else if (isSpecialPicking) stepText = "Tayyorlanmoqda";
          else if (isCurrent) stepText = pendingTexts[index];
          else stepText = completedTexts[index];`;
const newTextCond = `          String stepText = "";
          if (isCompleted) stepText = completedTexts[index];
          else if (isCurrent) stepText = pendingTexts[index];
          else stepText = completedTexts[index];`;
code = code.replace(oldTextCond, newTextCond);

// 7. Fix _getStep
const oldGetStep = `  int _getStep(String? status) {
    if (status == null) return 0;
    final s = status.toLowerCase();
    if (s.contains('yangi') || s == 'pending') return 0;
    if (s.contains('qabul') || s == 'accepted') return 1;
    if (s.contains('tayyorlanmoqda') || s == 'picking') return 1; // Special picking state
    if (s == 'packed' || s.contains('tayyor')) return 2; // Kuryer kutilmoqda
    if (s.contains('yo\\'lda') || s == 'delivering') return 3; // Kuryer maxsulotni yetkazmoqda
    if (s.contains('yetkazildi') || s == 'delivered') return 4;
    return 0;
  }`;
const newGetStep = `  int _getStep(String? status) {
    if (status == null) return 0;
    final s = status.toLowerCase();
    if (s.contains('yangi') || s == 'pending') return 0;
    if (s.contains('qabul') || s == 'accepted' || s.contains('tayyorlanmoqda') || s == 'picking') return 1;
    if (s == 'packed' || s.contains('tayyor')) return 2;
    if (s.contains('yo\\'lda') || s == 'delivering') return 3;
    if (s.contains('yetkazildi') || s == 'delivered') return 4;
    return 0;
  }`;
code = code.replace(oldGetStep, newGetStep);

fs.writeFileSync(path, code, 'utf8');
console.log('Successfully completed 7 replacements in orders_screen.dart!');
