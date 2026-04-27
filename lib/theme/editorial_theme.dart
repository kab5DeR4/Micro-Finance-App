import 'package:flutter/material.dart';

class EditorialTheme {
  static const Color bg = Color(0xFFF5F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF1E3A8A); // Deep Editorial Navy
  static const Color accentDark = Color(0xFF0F172A); // Rich Slate
  static const Color textMain = Color(0xFF292929);
  static const Color textDim = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color danger = Color(0xFFC94A4A);

  static const String fontHeading = 'Georgia';
  static const String fontBody = 'Helvetica';

  static InputDecoration inputTheme(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: textDim,
        fontSize: 14,
        fontFamily: fontBody,
        fontWeight: FontWeight.bold,
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: border, width: 1.5),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: textMain, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: danger, width: 1.5),
      ),
      fillColor: Colors.transparent,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
    );
  }
}

class CleanFadeIn extends StatelessWidget {
  final Widget child;
  final int index;

  const CleanFadeIn({super.key, required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        final double delayedVal = (val - (index * 0.1)).clamp(0.0, 1.0);
        final double normalizedVal = delayedVal < 0
            ? 0
            : (delayedVal * (1 / (1 - (index * 0.1).clamp(0.0, 0.99))));

        return Opacity(
          opacity: normalizedVal.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - normalizedVal.clamp(0.0, 1.0))),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
