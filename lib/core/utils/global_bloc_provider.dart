import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';

interface class IAuthBlocProvider {
  List<SingleChildWidget> get providers => [
    BlocProvider.value(value: getIt<AuthCubit>()),
  ];
}

interface class IGlobalBlocProvider {
  List<SingleChildWidget> get providers => [...IAuthBlocProvider().providers];
}

class GlobalBlocProvider extends IGlobalBlocProvider {}
