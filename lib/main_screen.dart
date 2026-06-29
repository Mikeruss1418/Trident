import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:trident/core/routes/route_config.dart';
import 'package:trident/core/utils/global_bloc_provider.dart';
import 'package:trident/core/utils/theme/theme.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: MediaQuery.of(context).size,
      minTextAdapt: true,
      builder: (_, child) {
        return MultiBlocProvider(
          providers: GlobalBlocProvider().providers,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: RouteConfig.router,
            title: 'Trident',
          ),
        );
      },
    );
  }
}
