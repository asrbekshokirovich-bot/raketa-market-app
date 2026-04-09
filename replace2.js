const fs = require('fs');
const file = 'c:/Users/User/Desktop/Abulfayiz project app/supermarket_app/lib/screens/orders_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

const startIndex = txt.indexOf('  Widget _buildStepper');
const endIndex = txt.indexOf('  int _getStep(');

if (startIndex === -1 || endIndex === -1) {
  console.log('Cannot find bounds');
  process.exit(1);
}

const replacement = `  Widget _buildStepper(BuildContext context, int currentStep, bool isDark) {
    final pendingTexts = [
      "Qabul qilish kutilmoqda", 
      "Tayyorlash kutilmoqda", 
      "Kuryer kutilmoqda", 
      "Qabul qilinishi kutilmoqda"
    ];
    final completedTexts = [
      "Qabul qilingan", 
      "Tayyorlanmoqda", 
      "Yo'lda", 
      "Yetkazildi"
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(4, (index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          final isFuture = index > currentStep;
          final isLast = index == 3;

          final activeColor = isCompleted ? Colors.green : const Color(0xFFFF7A00);
          final bool isCardActive = isCompleted || isCurrent;

          String stepText = "";
          if (isCompleted) stepText = completedTexts[index];
          else if (isCurrent) stepText = pendingTexts[index];
          else stepText = completedTexts[index];

          final translatedText = context.read<LocalizationProvider>().translate(stepText);
          final finalText = translatedText == stepText ? stepText : translatedText;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Step Card
              Container(
                constraints: const BoxConstraints(minWidth: 170),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
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
                ),
              ),
              
              // Connecting Line
              if (!isLast)
                Container(
                  width: 30,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : (isDark ? Colors.grey[800] : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

`;

const newText = txt.substring(0, startIndex) + replacement + txt.substring(endIndex);
fs.writeFileSync(file, newText, 'utf8');
console.log('Success!');
