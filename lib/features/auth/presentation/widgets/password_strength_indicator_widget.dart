import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/auth/domains/models/password_requirements_model.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordRequirementsModel requirements;

  const PasswordStrengthIndicator({super.key, required this.requirements});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: requirements.score / 5,
          backgroundColor: AppColors.textTertiary,
          color: AppColors.success,
          borderRadius: BorderRadius.circular(12.r),
          minHeight: 6.h,
        ),

        12.verticalSpace,

        _Requirement(
          passed: requirements.hasMinLength,
          text: 'At least 12 characters',
        ),

        _Requirement(
          passed: requirements.hasUppercase,
          text: 'One uppercase letter',
        ),

        _Requirement(
          passed: requirements.hasLowercase,
          text: 'One lowercase letter',
        ),

        _Requirement(passed: requirements.hasNumber, text: 'One number'),

        _Requirement(
          passed: requirements.hasSpecialCharacter,
          text: 'One special character',
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  final bool passed;
  final String text;

  const _Requirement({required this.passed, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18.sp,
            color: passed ? AppColors.success : AppColors.textTertiary,
          ),
          8.horizontalSpace,
          TextWidget(text),
        ],
      ),
    );
  }
}
