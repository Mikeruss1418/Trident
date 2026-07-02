enum DeviceTypeEnum { mobile, tablet }

enum ScreenOrientation { portrait, landscape }

enum WidthClass {
  compact, // < 600 dp (Phone portrait, or tight split-screen)
  medium, // 600 dp to 839 dp (Tablet portrait, landscape phone)
  expanded, // >= 840 dp (Tablet landscape, desktop)
}
