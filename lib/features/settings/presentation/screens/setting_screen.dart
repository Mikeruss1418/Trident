import 'package:trident/core/utils/app_imports.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextWidget('Settings', textType: TextType.headlineLarge),
      ),
    );
  }
}
