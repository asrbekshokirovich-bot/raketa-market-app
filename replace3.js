const fs = require('fs');
const file = 'c:/Users/User/Desktop/Abulfayiz project app/supermarket_app/lib/screens/orders_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

const t1 = `  Widget _buildStepper(BuildContext context, int currentStep, bool isDark) {`;
const r1 = `  Widget _buildStepper(BuildContext context, int currentStep, bool isDark, String status) {`;

const t2 = `          final isLast = index == 3;

          final activeColor = isCompleted ? Colors.green : const Color(0xFFFF7A00);
          final bool isCardActive = isCompleted || isCurrent;

          String stepText = "";
          if (isCompleted) stepText = completedTexts[index];
          else if (isCurrent) stepText = pendingTexts[index];
          else stepText = completedTexts[index];`;

const r2 = `          final isLast = index == 3;
          final isSpecialPicking = isCurrent && index == 1 && (status.toLowerCase().contains('tayyorlanmoqda') || status.toLowerCase() == 'picking');

          final activeColor = isCompleted ? Colors.green : (isSpecialPicking ? Colors.green : const Color(0xFFFF7A00));
          final bool isCardActive = isCompleted || isCurrent;

          String stepText = "";
          if (isCompleted) stepText = completedTexts[index];
          else if (isSpecialPicking) stepText = "Tayyorlanmoqda";
          else if (isCurrent) stepText = pendingTexts[index];
          else stepText = completedTexts[index];`;

const t3 = `  int _getStep(String? status) {
    if (status == null) return 0;
    final s = status.toLowerCase();
    if (s.contains('yangi') || s == 'pending') return 0;
    if (s.contains('qabul') || s == 'accepted') return 1;
    if (s.contains('tayyorlanmoqda') || s == 'picking') return 2;
    if (s.contains('tayyor') || s.contains('yo\\'lda') || s == 'packed' || s == 'delivered') return 3;
    return 0;
  }`;

const r3 = `  int _getStep(String? status) {
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

const t4 = `_buildStepper(context, currentOrder.currentStep, isDark),`;
const r4 = `_buildStepper(context, currentOrder.currentStep, isDark, currentOrder.status),`;

txt = txt.replace(t1, r1);
txt = txt.replace(t2.replace(/\\r\\n/g, '\\n'), r2.replace(/\\r\\n/g, '\\n')); // Fallback for JS newlines
txt = txt.replace(t3.replace(/\\r\\n/g, '\\n'), r3.replace(/\\r\\n/g, '\\n')); 
txt = txt.replace(t4, r4);

// Additional exact substring replacements to bypass node RegExp CRLF parsing issues
if (!txt.includes('isSpecialPicking')) {
    txt = txt.substring(0, txt.indexOf(t2)) + r2 + txt.substring(txt.indexOf(t2) + t2.length);
}
if (!txt.includes('Special picking state')) {
    txt = txt.substring(0, txt.indexOf(t3)) + r3 + txt.substring(txt.indexOf(t3) + t3.length);
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Stepper logic updated successfully!');
