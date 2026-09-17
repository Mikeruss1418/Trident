import 'package:trident/core/constants/assets_path.dart';
import 'package:trident/core/extensions/widget_extension.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/home/data/constants/home_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenPadding(
        child: Column(
          children: [
            20.verticalSpace,
            _buildLogo(),
            24.verticalSpace,
            _buildGlobalSearchPlaceHolder().onTap(() {
              // implementation of the global search for the docs
            }),
            14.verticalSpace,
            _buildOverviewCard(),
            14.verticalSpace,
            GridView.builder(
              itemCount: HomeConstants.services.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (context, index) => Container(),
            ),
          ],
        ),
      ),
    );
  }

  Container _buildOverviewCard() {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              /// for now i am providing static value here
              TextWidget(
                0.toString(),
                textType: TextType.custom,
                textOptions: TextOptions(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.h,
                      decoration: ShapeDecoration(
                        color: AppColors.success,
                        shape: CircleBorder(),
                      ),
                    ),
                    6.horizontalSpace,
                    TextWidget(
                      'Unlocked',
                      textType: TextType.custom,
                      color: AppColors.success,
                      textOptions: TextOptions(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          TextWidget(
            'documents encrypted',
            color: AppColors.textTertiary,
            textType: TextType.bodySmall,
          ),
          24.verticalSpace,
          _buildRow(
            icon: Icons.shield_outlined,
            content: Text.rich(
              TextSpan(
                style: TextTheme.of(context).bodySmall,
                children: [
                  TextSpan(
                    text: 'Unlocked with ',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  TextSpan(
                    text: 'fingerprint',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' 4 min ago',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          8.verticalSpace,
          _buildRow(
            icon: Icons.access_time_rounded,
            content: Text.rich(
              TextSpan(
                style: TextTheme.of(context).bodySmall,
                children: [
                  TextSpan(
                    text: 'Auto-locks after ',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  TextSpan(
                    text: ' 2 min ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: 'idle',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            // content: 'Auto-locks after. 2 min dile',
          ),
        ],
      ),
    );
  }

  Container _buildGlobalSearchPlaceHolder() {
    return Container(
      width: double.maxFinite,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        mainAxisAlignment: .start,
        children: [
          Icon(Icons.search),
          20.horizontalSpace,
          TextWidget("Search", textType: TextType.bodyLarge),
        ],
      ),
    );
  }

  Hero _buildLogo() {
    return Hero(
      tag: 'logo',
      curve: Curves.easeIn,
      child:
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.onPrimary,
                radius: 24.r,
                child: Image.asset(AssetsPath.logoPNG),
              ),
              14.horizontalSpace,
              TextWidget(
                'Trident',
                textType: TextType.custom,
                color: AppColors.primary,
                textOptions: TextOptions(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ).onTap(
            () =>
                getIt<NavigationService>().navigateTo(RouteNames.profileRoute),
          ),
    );
  }

  Widget _buildRow({required IconData icon, required dynamic content}) {
    return Row(
      mainAxisSize: .min,
      mainAxisAlignment: .start,
      children: [
        Icon(icon, color: AppColors.primary, size: 15.r),
        12.horizontalSpace,
        content is Widget
            ? content
            : TextWidget(
                content,
                textType: TextType.bodySmall,
                color: AppColors.textTertiary,
              ),
      ],
    );
  }
}
