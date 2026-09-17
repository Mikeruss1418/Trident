import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';
import 'package:trident/features/dashboard/presentation/cubits/bottom_nav_cubit.dart';

interface class IAuthBlocProvider {
  List<SingleChildWidget> get providers => [
    BlocProvider.value(value: getIt<AuthCubit>()),
  ];
}

interface class IDashboardBlocProvider {
  List<SingleChildWidget> get dashboardProviders => [
    BlocProvider.value(value: getIt<BottomNavCubit>()),
  ];
}

interface class IGlobalBlocProvider {
  List<SingleChildWidget> get providers => [
    ...IAuthBlocProvider().providers,
    ...IDashboardBlocProvider().dashboardProviders,
  ];
}

class GlobalBlocProvider extends IGlobalBlocProvider {}
