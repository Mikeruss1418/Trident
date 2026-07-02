import 'package:trident/features/auth/domains/models/password_requirements_model.dart';

class PasswordValidatorService {
  static PasswordRequirementsModel validate(String password) {
    return PasswordRequirementsModel(
      hasMinLength: password.length >= 12,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasNumber: RegExp(r'\d').hasMatch(password),
      hasSpecialCharacter: RegExp(
        r'[!@#$%^&*(),.?":{}|<>_\-+=~`/\\[\]]',
      ).hasMatch(password),
    );
  }

  static String? validator(String? value) {
    final password = value ?? '';

    final result = validate(password);

    if (password.isEmpty) {
      return 'Master password is required';
    }

    if (!result.isValid) {
      return 'Password does not meet the required criteria';
    }

    return null;
  }
}
