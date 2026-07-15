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

  // Dynamic getters based on BuildContext for light/dark support
  static Color textMain(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light ? const Color(0xFF0F172A) : Colors.white;
  }
  static Color textMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light ? const Color(0xFF475569) : const Color(0xFF94A3B8);
  }
  static Color textMutedLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light ? const Color(0xFF64748B) : const Color(0xFF64748B);
  }
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
      fontFamily: 'Outfit',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PremiumColors.bgDarkSecondary,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: PremiumColors.cardBorder, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: PremiumColors.cardBorder, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: PremiumColors.primaryLight, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: PremiumColors.primary,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: PremiumColors.primary,
        secondary: PremiumColors.accent,
        background: Color(0xFFF1F5F9),
        surface: Colors.white,
      ),
      fontFamily: 'Outfit',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF475569)),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: PremiumColors.primaryLight, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          borderRadius: BorderRadius.circular(16),
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Stack(
      children: [
        // Background base
        Container(
          color: isLight ? const Color(0xFFF1F5F9) : PremiumColors.bgDark,
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
              color: PremiumColors.primary.withOpacity(isLight ? 0.08 : 0.2),
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
              color: const Color(0xFF6366F1).withOpacity(isLight ? 0.04 : 0.08),
            ),
          ),
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                isLight ? Colors.white24 : Colors.black45,
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    Widget card = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(0.85) : PremiumColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor ?? (isLight ? const Color(0xFFE2E8F0) : PremiumColors.cardBorder),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isLight ? 0.05 : 0.2),
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
