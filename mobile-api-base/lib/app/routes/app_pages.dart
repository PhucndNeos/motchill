import 'package:get/get.dart';

import '../../features/detail/detail_binding.dart';
import '../../features/detail/detail_view.dart';
import '../../features/category/category_view.dart';
import '../../features/home/home_binding.dart';
import '../../features/home/home_view.dart';
import '../../features/search/search_binding.dart';
import '../../features/search/search_view.dart';
import '../../features/player/player_binding.dart';
import '../../features/player/player_view.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.category,
      page: () => const CategoryView(),
      binding: SearchBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchView(),
      binding: SearchBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.detail,
      page: () => const DetailView(),
      binding: DetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.play,
      page: () => const PlayerView(),
      binding: PlayerBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
