import 'package:local_auth/local_auth.dart';

abstract class BiometricService {
  Future<bool> isAvailable();
  Future<List<BiometricType>> getAvailableBiometrics();
  Future<bool> authenticate({
    required String localizedReason,
    String? cancelButton,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  });
  Future<void> invalidate();
}