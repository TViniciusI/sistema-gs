import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GsTheme {
  static const navy = Color(0xFF0C1F33);
  static const navyDeep = Color(0xFF07121F);
  static const navyLight = Color(0xFF17385C);
  static const brass = Color(0xFFC59E39);
  static const brassLight = Color(0xFFE9CF7A);
  static const paper = Color(0xFFF4F0E6);
  static const ink = Color(0xFF1A2330);
  static const muted = Color(0xFF5C6570);

  static const radius = 14.0;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyLight, navy, navyDeep],
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFB88F2E), brassLight, Color(0xFFB88F2E)],
  );

  static List<BoxShadow> get softShadow => const [
    BoxShadow(
      color: Color(0x140C1F33),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  static ThemeData get data {
    final base = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
    );
    const rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
    );
    const fieldRadius = BorderRadius.all(Radius.circular(12));
    return ThemeData(
      colorScheme: base.copyWith(
        primary: navy,
        onPrimary: paper,
        secondary: brass,
        onSecondary: navy,
        tertiary: brass,
        surface: paper,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: brass, width: 2.5)),
        titleTextStyle: TextStyle(
          color: paper,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: paper),
        actionsIconTheme: IconThemeData(color: brassLight),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navy,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brass,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? brassLight
                : const Color(0xB3F4F0E6),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? navy
                : const Color(0xB3F4F0E6),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: rounded.copyWith(
          side: const BorderSide(color: Color(0x1A0C1F33)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: paper,
          minimumSize: const Size.fromHeight(54),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: navy,
          side: const BorderSide(color: navy, width: 1.4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navy,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brass,
        foregroundColor: navy,
        elevation: 2,
        extendedTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: TextStyle(fontSize: 16, color: muted),
        floatingLabelStyle: TextStyle(
          fontSize: 16,
          color: navy,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(fontSize: 16, color: Color(0x990C1F33)),
        prefixIconColor: navy,
        border: OutlineInputBorder(borderRadius: fieldRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: Color(0x330C1F33)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: brass, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: TextStyle(color: paper, fontSize: 15, height: 1.35),
        actionTextColor: brassLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: brass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: Color(0x33C59E39),
        side: BorderSide(color: Color(0x330C1F33)),
        labelStyle: TextStyle(color: navy, fontWeight: FontWeight.w600),
        shape: StadiumBorder(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brass,
        linearTrackColor: Color(0x22C59E39),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brass : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? navy : null,
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1F0C1F33)),
      listTileTheme: const ListTileThemeData(iconColor: navy),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 17, height: 1.35, color: ink),
        bodyMedium: TextStyle(fontSize: 16, height: 1.4, color: ink),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
      ),
      pageTransitionsTheme: kIsWeb
          ? PageTransitionsTheme(
              builders: {
                for (final platform in TargetPlatform.values)
                  platform: const FadeUpwardsPageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(),
      useMaterial3: true,
    );
  }
}
