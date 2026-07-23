import 'package:flutter/material.dart';

/// Direção visual "etiqueta de gôndola": papel quente + tinta escura,
/// marca índigo, âmbar como acento — e o VERDE reservado exclusivamente
/// para semântica de preço/economia (o erro do concorrente é usar verde
/// para tudo, o que zera a capacidade de sinalizar "barato").
///
/// Contrastes dos pares principais verificados >= 4,5:1 (WCAG AA).
abstract final class AppColors {
  /// Fundo: branco quente, não clínico. Reduz ofuscamento sob a luz
  /// fluorescente do mercado.
  static const papel = Color(0xFFFBF7F0);

  /// Texto principal. 17,2:1 sobre papel.
  static const tinta = Color(0xFF171412);

  /// Texto secundário. ~7:1 sobre papel.
  static const tintaSuave = Color(0xFF5B534A);

  /// Marca: índigo-uva. Não é verde de fintech de propósito.
  static const marca = Color(0xFF2E2A5C);

  /// Acento âmbar — categoria, destaque. Nunca texto pequeno sobre claro.
  static const ambar = Color(0xFFF2A007);

  /// Verde SEMÂNTICO de preço/economia. Escurecido para passar AA
  /// sobre branco (o verde do concorrente reprova a 4,24:1).
  static const precoBom = Color(0xFF1E6B45);

  /// Bordas de card: linha, não sombra — sombra suave some em LCD de
  /// entrada sob luz forte.
  static const borda = Color(0xFFE7DFD2);

  static const cardBg = Colors.white;
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.marca,
        surface: AppColors.papel,
        onSurface: AppColors.tinta,
      ).copyWith(
        primary: AppColors.marca,
        // O par completo do âmbar: trocar só `secondary` deixaria os
        // `on*` calculados para a semente índigo — contraste quebrado.
        secondary: AppColors.ambar,
        onSecondary: AppColors.tinta,
        secondaryContainer: const Color(0xFFFFE3B3),
        onSecondaryContainer: AppColors.tinta,
        outlineVariant: AppColors.borda,
      );

  final base = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.papel,
    useMaterial3: true,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.papel,
      foregroundColor: AppColors.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: AppColors.borda),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.marca,
      foregroundColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.marca,
        foregroundColor: Colors.white,
        // Alvo de toque >= 48dp (o concorrente falha nisso).
        minimumSize: const Size(48, 48),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? AppColors.precoBom : null,
      ),
    ),
    // Chips (seletor de unidade): padding maior para dedo; a área de
    // toque de 48dp vem do materialTapTargetSize `padded` herdado do
    // ThemeData (default no Android), aplicado pelo próprio RawChip.
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: AppColors.borda),
  );
}

/// Números de preço sempre tabulares: colunas de dinheiro alinham.
const priceFontFeatures = [FontFeature.tabularFigures()];
