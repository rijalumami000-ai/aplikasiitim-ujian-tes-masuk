import 'package:flutter/material.dart';

class PremiumColors {
  // Slate/Zinc Dark Backgrounds
  static const Color bgDark = Color(0xFF0F172A);
  static const Color bgDarkSecondary = Color(0xFF1E293B);
  static const Color cardBg = Color(0x1FFFFFFF); // Glassmorphism base
  static const Color cardBorder = Color(0x1AFFFFFF); // Soft white border

  // Emerald Greens
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primaryDark = Color(0xFF042F2C);
  static const Color accent = Color(0xFF10B981);

  // Status colors
  static const Color sifirColor = Color(0xFFF59E0B); // Amber
  static const Color satuColor = Color(0xFF3B82F6);  // Blue
  static const Color spColor = Color(0xFF8B5CF6);    // Purple
  static const Color borderHighlight = Color(0xFF10B981);

  // Greys and Texts
  static const Color textMain = Colors.white;
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textMutedLight = Color(0xFF64748B);
}

class PremiumTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: PremiumColors.primary,
      scaffoldBackgroundColor: PremiumColors.bgDark,
      cardColor: PremiumColors.bgDarkSecondary,
      colorScheme: const ColorScheme.dark(
        primary: PremiumColors.primary,
        secondary: PremiumColors.accent,
        background: PremiumColors.bgDark,
        surface: PremiumColors.bgDarkSecondary,
      ),
      fontFamily: 'Outfit', // We'll map standard fallback sans-serif if Outfit is not found
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: PremiumColors.textMain),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: PremiumColors.textMain),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: PremiumColors.textMain),
        bodyLarge: TextStyle(fontSize: 16, color: PremiumColors.textMain),
        bodyMedium: TextStyle(fontSize: 14, color: PremiumColors.textMuted),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PremiumColors.textMain),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PremiumColors.bgDarkSecondary,
        labelStyle: const TextStyle(color: PremiumColors.textMuted),
        hintStyle: const TextStyle(color: PremiumColors.textMutedLight),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PremiumColors.cardBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PremiumColors.cardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PremiumColors.primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }
}

// Background dekorasi dengan gradient dan pendaran cahaya (glow effect)
class PremiumBackground extends StatelessWidget {
  final Widget child;

  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background base
        Container(
          color: PremiumColors.bgDark,
        ),
        // Glow effect 1: Pojok kanan atas (Emerald)
        Positioned(
          top: -150,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PremiumColors.primary.withOpacity(0.2),
            ),
          ),
        ),
        // Glow effect 2: Pojok kiri bawah (Purple/Blue-ish hint for contrast)
        Positioned(
          bottom: -150,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.08),
            ),
          ),
        ),
        // Gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.black45,
              ],
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}

// Kartu Glassmorphism (Glass Card)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor ?? PremiumColors.cardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: card,
      );
    }

    return card;
  }
}

// Tombol Premium
class PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? color;

  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: color == null
            ? const LinearGradient(
                colors: [PremiumColors.primary, PremiumColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: color,
        boxShadow: [
          BoxShadow(
            color: (color ?? PremiumColors.primary).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
