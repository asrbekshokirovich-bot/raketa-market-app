import 'package:flutter/material.dart';

class CurvedNavPainter extends CustomPainter {
  final double x;
  final Color color;
  final bool isDark;

  CurvedNavPainter({
    required this.x,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Starting point (top left)
    path.moveTo(0, 0);
    
    // Notch dimensions
    const double notchWidth = 110.0;
    const double notchHeight = 44.0;
    
    // Calculate the start and end of the notch based on fractional x (0.0 to 1.0)
    final double centerX = x * size.width;
    final double startNotch = centerX - notchWidth / 2;
    final double endNotch = centerX + notchWidth / 2;

    // Draw to the start of the notch
    path.lineTo(startNotch, 0);

    // Smooth Bézier curve for the notch
    path.cubicTo(
      startNotch + notchWidth * 0.2, // ctrl1 x
      0,                            // ctrl1 y
      startNotch + notchWidth * 0.25, // ctrl2 x
      notchHeight,                  // ctrl2 y
      centerX,                      // end x
      notchHeight,                  // end y
    );

    path.cubicTo(
      endNotch - notchWidth * 0.25, // ctrl1 x
      notchHeight,                   // ctrl1 y
      endNotch - notchWidth * 0.2,   // ctrl2 x
      0,                             // ctrl2 y
      endNotch,                      // end x
      0,                             // end y
    );

    // Draw to the top right
    path.lineTo(size.width, 0);
    
    // Bottom right
    path.lineTo(size.width, size.height);
    
    // Bottom left
    path.lineTo(0, size.height);
    
    path.close();

    // Draw shadow for depth (chotki look)
    canvas.drawShadow(path, Colors.black.withOpacity(0.5), 8.0, false);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CurvedNavPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.color != color || oldDelegate.isDark != isDark;
  }
}
