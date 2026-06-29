import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/encrytion/vault_encryption/vault_encryption_service.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _masterPasswordController =
      TextEditingController();

  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _masterPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: .center,
            children: [
              Text('Sign Up'),
              12.verticalSpace,
              TextFormField(
                controller: _masterPasswordController,
                obscureText: true,
                decoration: InputDecoration(hintText: "Master Password"),
              ),
              12.verticalSpace,
              BlocListener<AuthCubit, AuthStatus>(
                listener: (context, state) {
                  if (state == AuthStatus.authenticated) {
                    getIt<NavigationService>().navigateTo(RouteNames.homeRoute);
                  } else {
                    // throws WrongPasswordException
                    WrongPasswordException();
                  }
                },
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      getIt<AuthCubit>().login(_masterPasswordController.text);
                    }
                  },
                  child: const Text("Sign Up"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
