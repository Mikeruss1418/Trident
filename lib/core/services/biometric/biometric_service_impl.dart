import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/core/services/biometric/biometric_service.dart';
import 'package:trident/core/utils/logger/app_logger.dart';

@LazySingleton(as: BiometricService)
class BiometricServiceImpl implements BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      final List<BiometricType> availableBiometrics = await _localAuth
          .getAvailableBiometrics();
      return await _localAuth.canCheckBiometrics &&
          availableBiometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    String? cancelButton,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: stickyAuth,
      );
    } on PlatformException catch (e, _) {
      AppLogger.debug('BiometricAuth failed: ${e.code} — ${e.message}');
      // Return false instead of rethrowing — biometric auth failure should
      // not crash the app, it should just report authentication failure.
      return false;
    }
  }

  @override
  Future<void> invalidate() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (_) {}
  }
}
