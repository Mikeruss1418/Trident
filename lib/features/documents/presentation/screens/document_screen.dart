import 'package:trident/core/utils/app_imports.dart';

class DocumentScreen extends StatelessWidget {
  const DocumentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextWidget('Documents', textType: TextType.headlineLarge),
      ),
    );
  }
}
