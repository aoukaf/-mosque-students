import 'package:flutter/material.dart';

/// نظام التكيف التلقائي مع حجم الشاشة
class Responsive {
  final BuildContext context;
  late final double _width;
  late final double _height;
  Responsive(this.context) {
    final mq = MediaQuery.of(context);
    _width = mq.size.width;
    _height = mq.size.height;
  }

  // ========== نوع الجهاز ==========
  bool get isSmallPhone => _width < 360;       // هواتف صغيرة (Galaxy A series قديمة)
  bool get isNormalPhone => _width >= 360 && _width < 414; // هواتف عادية (iPhone 12, Galaxy S)
  bool get isLargePhone => _width >= 414 && _width < 600; // هواتف كبيرة (iPhone Pro Max, S Ultra)
  bool get isTablet => _width >= 600;           // تابلت

  // ========== حجم الشاشة المرجعي ==========
  // نستخدم 375 كعرض مرجعي (iPhone 12 عادي)
  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  /// نسبة تكيف العرض
  double get scaleW => _width / _designWidth;

  /// نسبة تكيف الارتفاع
  double get scaleH => _height / _designHeight;

  /// نسبة تكيف ذكية (تأخذ الأصغر لتجنب تمدد مبالغ)
  double get scale => scaleW < scaleH ? scaleW : scaleH;

  // ========== قياسات تكيفية ==========

  /// حجم خط تكيفي
  double fontSize(double size) {
    final scaled = size * scale;
    // حد أدنى وأقصى لحجم الخط
    return scaled.clamp(size * 0.8, size * 1.3);
  }

  /// padding/margin تكيفي
  double sp(double size) => (size * scaleW).clamp(size * 0.75, size * 1.4);

  /// حجم أيقونة تكيفي
  double iconSize(double size) => (size * scale).clamp(size * 0.8, size * 1.3);

  /// نصف قطر زوايا تكيفي
  double radius(double r) => (r * scale).clamp(r * 0.8, r * 1.2);

  // ========== padding جاهزة ==========
  EdgeInsets get pagePadding => EdgeInsets.all(sp(16));
  EdgeInsets get cardPadding => EdgeInsets.all(sp(14));
  EdgeInsets get smallPadding => EdgeInsets.all(sp(8));

  // ========== أبعاد جاهزة ==========
  double get avatarRadius {
    if (isSmallPhone) return 22;
    if (isTablet) return 36;
    return 26;
  }

  double get cardBorderRadius => radius(16);

  // ========== عدد الأعمدة في Grid ==========
  int get gridColumns => isTablet ? 3 : (isLargePhone ? 3 : 2);

  // ========== نسبة أبعاد Grid ==========
  double get gridAspectRatio {
    if (isSmallPhone) return 1.3;
    if (isTablet) return 1.6;
    return 1.45;
  }

  // للوصول السهل بدون إنشاء كائن
  static Responsive of(BuildContext context) => Responsive(context);
}

/// Extension سهل الاستخدام على BuildContext
extension ResponsiveExt on BuildContext {
  Responsive get r => Responsive(this);
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isTablet => MediaQuery.of(this).size.width >= 600;
  bool get isSmallPhone => MediaQuery.of(this).size.width < 360;
}

/// Widget يعيد البناء عند تغيير حجم الشاشة (rotate / resize)
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Responsive r) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) => builder(ctx, Responsive(ctx)),
    );
  }
}
