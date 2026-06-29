
import 'package:flutter/material.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';
import 'package:trident/injectables/injectable.dart';
import 'package:trident/main_screen.dart';

class EntryPoint {
  Future<void> initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Di injection
    await configureDependencies();
    await getIt<AuthCubit>().initialize();

    // start app
    runApp(const MainScreen());
  }
}