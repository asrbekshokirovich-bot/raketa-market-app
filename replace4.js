const fs = require('fs');
const file = 'c:/Users/User/Desktop/Abulfayiz project app/supermarket_app/lib/screens/orders_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

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

const startIndex = txt.indexOf('  int _getStep(String? status) {');
const endIndex = txt.indexOf('  @override', startIndex);

if (startIndex !== -1 && endIndex !== -1) {
    txt = txt.substring(0, startIndex) + r3 + "\\n\\n" + txt.substring(endIndex);
    fs.writeFileSync(file, txt, 'utf8');
    console.log('Success!');
} else {
    console.log('Failed to find boundaries');
}
