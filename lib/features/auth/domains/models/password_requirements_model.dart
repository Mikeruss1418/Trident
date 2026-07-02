class PasswordRequirementsModel {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialCharacter;

  const PasswordRequirementsModel({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialCharacter,
  });

  int get score => [
    hasMinLength,
    hasUppercase,
    hasLowercase,
    hasNumber,
    hasSpecialCharacter,
  ].where((e) => e).length;

  bool get isValid => score == 5;
}
