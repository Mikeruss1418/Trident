import 'package:trident/core/extensions/app_extensions.dart';
import 'package:trident/core/utils/app_imports.dart';

enum TextType {
  /// font size: 32.sp, font weight: w500
  displayLarge,

  /// font size: 28.sp, font weight: w500
  displayMedium,

  /// font size: 24.sp, font weight: w500
  displaySmall,

  /// font size: 22.sp, font weight: w500
  headlineLarge,

  /// font size: 20.sp, font weight: w500
  headlineMedium,

  /// font size: 18.sp, font weight: w500
  headlineSmall,

  /// font size: 18.sp, font weight: w500
  titleLarge,

  /// font size: 16.sp, font weight: w500
  titleMedium,

  /// font size: 14.sp, font weight: w500
  titleSmall,

  /// font size: 16.sp, font weight: w400
  bodyLarge,

  /// font size: 14.sp, font weight: w400
  bodyMedium,

  /// font size: 12.sp, font weight: w400
  bodySmall,

  /// font size: 14.sp, font weight: w500
  labelLarge,

  /// font size: 12.sp, font weight: w500
  labelMedium,

  /// font size: 10.sp, font weight: w500
  labelSmall,

  /// Custom typography configuration.
  ///
  /// Requires [TextOptions] to be provided.
  custom,
}

/// Overrides for [TextType.custom]. All fields optional — falls back to theme defaults.

@immutable
class TextOptions {
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final double? height;
  final double? letterSpacing;
  final TextDecoration? decoration;
  final String? fontFamily;

  const TextOptions({
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.height,
    this.letterSpacing,
    this.decoration,
    this.fontFamily,
  });
}

class TextWidget extends StatelessWidget {
  final String text;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextType textType;
  final TextScaler? textScaler;
  final TextOptions? textOptions;
  final Color? color;

  const TextWidget(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.textType = TextType.bodyMedium,
    this.textScaler,
    this.color,
    this.textOptions,
  }) : assert(
         textType != TextType.custom || textOptions != null,
         'TextType.custom requires textOptions to be provided.',
       );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _getTextStyle(context),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      textScaler: textScaler,
    );
  }

  TextStyle _getTextStyle(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    // Explicit null fallback — never bang theme colors.
    final resolvedColor =
        color ?? tt.bodyMedium?.color ?? AppColors.textPrimary;
    TextStyle? base;
    switch (textType) {
      case TextType.displayLarge:
        base = tt.displayLarge;
      case TextType.displayMedium:
        base = tt.displayMedium;
      case TextType.displaySmall:
        base = tt.displaySmall;
      case TextType.headlineLarge:
        base = tt.headlineLarge;
      case TextType.headlineMedium:
        base = tt.headlineMedium;
      case TextType.headlineSmall:
        base = tt.headlineSmall;
      case TextType.titleLarge:
        base = tt.titleLarge;
      case TextType.titleMedium:
        base = tt.titleMedium;
      case TextType.titleSmall:
        base = tt.titleSmall;
      case TextType.bodyLarge:
        base = tt.bodyLarge;
      case TextType.bodyMedium:
        base = tt.bodyMedium;
      case TextType.bodySmall:
        base = tt.bodySmall;
      case TextType.labelLarge:
        base = tt.labelLarge;
      case TextType.labelMedium:
        base = tt.labelMedium;
      case TextType.labelSmall:
        base = tt.labelSmall;
      case TextType.custom:
        return _customStyle(context, resolvedColor);
    }
    return (base ?? tt.bodyMedium!).copyWith(color: resolvedColor);
  }

  TextStyle _customStyle(BuildContext context, Color resolvedColor) {
    return context.getFontStyle(
      fontSize: textOptions?.fontSize ?? 14.sp,
      fontWeight: textOptions?.fontWeight,
      fontStyle: textOptions?.fontStyle,
      height: textOptions?.height,
      letterSpacing: textOptions?.letterSpacing,
      decoration: textOptions?.decoration,
      fontFamily: textOptions?.fontFamily,
      color: resolvedColor,
    );
  }
}
