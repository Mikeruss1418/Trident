import 'package:trident/core/storage/secure_storage/secure_storage_service.dart';
import 'package:trident/core/storage/secured_storage_keys.dart';
import 'package:trident/core/utils/app_imports.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<String?> getSalt() async {
    final salt = await getIt<SecureStorageService>().readSecureData(
      key: SecureStorageKeys.salt,
    );
    return salt;
  }

  Future<String?> getDEK() async {
    final salt = await getIt<SecureStorageService>().readSecureData(
      key: SecureStorageKeys.encryptedDEKBlob,
    );
    return salt;
  }

  Future<String?> getPswVerifier() async {
    final salt = await getIt<SecureStorageService>().readSecureData(
      key: SecureStorageKeys.passwordVerifierBlob,
    );
    return salt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextWidget("Home", textType: TextType.headlineLarge),
        actions: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: AppColors.info,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                  blurRadius: 4.r,
                ),
              ],
            ),
            child: Icon(Icons.add, color: AppColors.background),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            TextWidget(getSalt().toString()),
            TextWidget(getDEK().toString()),
            TextWidget(getPswVerifier().toString()),
          ],
        ),
      ),
    );
  }
}
