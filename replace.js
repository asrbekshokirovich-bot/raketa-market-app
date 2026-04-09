const fs = require('fs');
const file = 'c:/Users/User/Desktop/Abulfayiz project app/supermarket_app/lib/screens/orders_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

const t1 = `    final steps = [
      context.read<LocalizationProvider>().translate('qabul_kutilmoqda'), 
      context.read<LocalizationProvider>().translate('tayyorlanmoqda'), 
      context.read<LocalizationProvider>().translate('yetkazilmoqda'), 
      context.read<LocalizationProvider>().translate('yetkazildi')
    ];`;
const r1 = `    // Definining text formats per state
    final pendingTexts = [
      "Qabul qilish kutilmoqda", 
      "Tayyorlash kutilmoqda", 
      "Kuryer kutilmoqda",
      "Kuryer maxsulotni yetkazmoqda"
    ];
    
    final completedTexts = [
      "Qabul qilingan", 
      "Tayyorlanmoqda", 
      "Yo'lda", 
      "Yetkazildi"
    ];`;
txt = txt.replace(t1, r1);

const t2 = `        children: List.generate(steps.length, (index) {
          final isActive = index <= currentStep;
          final isLast = index == steps.length - 1;
          final activeColor = (index == 3) ? Colors.green 
                            : (index == 0 && currentStep > 0) ? Colors.green 
                            : const Color(0xFFFF7A00);`;
const r2 = `        children: List.generate(4, (index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          final isFuture = index > currentStep;
          final isLast = index == 3;

          final activeColor = isCompleted ? Colors.green : const Color(0xFFFF7A00);
          final bool isCardActive = isCompleted || isCurrent;

          // Determine the text based on state
          String stepText = "";
          if (isCompleted) stepText = completedTexts[index];
          else if (isCurrent) stepText = pendingTexts[index];
          else stepText = completedTexts[index]; // Default for future

          // Let's pass it to translator just in case it is registered, otherwise fallback to exact Uzbek string
          final translatedText = context.read<LocalizationProvider>().translate(stepText);
          final finalText = translatedText == stepText ? stepText : translatedText;`;
txt = txt.replace(t2, r2);

const t3 = `                decoration: BoxDecoration(
                  color: isActive ? activeColor.withOpacity(0.08) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? activeColor.withOpacity(0.5) : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    width: isActive ? 1.5 : 1,
                  ),
                  boxShadow: isActive ? [
                    BoxShadow(color: activeColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ] : [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circle inside Card
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? activeColor : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        shape: BoxShape.circle,
                        border: isActive ? Border.all(color: activeColor.withOpacity(0.3), width: 4) : null,
                      ),
                      child: Center(
                        child: (index == 0 && currentStep == 0) // Pending
                            ? const ThreeDotsLoading()
                            : isActive 
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text("\${index + 1}", style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Single Line Text
                    Text(
                      (index == 0 && currentStep > 0) ? context.read<LocalizationProvider>().translate('qabul_qilingan') : steps[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: (index == 0 && currentStep > 0) ? Colors.green : (isActive ? (isDark ? Colors.white : Colors.black87) : Colors.grey[500]),
                      ),
                    ),
                  ],
                ),`;
const r3 = `                decoration: BoxDecoration(
                  color: isCardActive ? activeColor.withOpacity(0.08) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCardActive ? activeColor.withOpacity(0.5) : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    width: isCardActive ? 1.5 : 1,
                  ),
                  boxShadow: isCardActive ? [
                    BoxShadow(color: activeColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ] : [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circle inside Card
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCardActive ? activeColor : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        shape: BoxShape.circle,
                        border: isCardActive ? Border.all(color: activeColor.withOpacity(0.3), width: 4) : null,
                      ),
                      child: Center(
                        child: isCurrent
                            ? const ThreeDotsLoading()
                            : isCompleted 
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text("\${index + 1}", style: GoogleFonts.montserrat(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Single Line Text
                    Text(
                      finalText,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: isCardActive ? FontWeight.bold : FontWeight.w600,
                        color: isCompleted ? Colors.green : (isCurrent ? const Color(0xFFFF7A00) : Colors.grey[500]),
                      ),
                    ),
                  ],
                ),`;
txt = txt.replace(t3.replace(/\\r\\n/g, '\\n'), r3);

const t4 = `color: index < currentStep ? const Color(0xFFFF7A00) : (isDark ? Colors.grey[800] : Colors.grey[300])`;
const r4 = `color: isCompleted ? Colors.green : (isDark ? Colors.grey[800] : Colors.grey[300])`;
txt = txt.replace(t4, r4);

fs.writeFileSync(file, txt, 'utf8');
console.log("Done.");
