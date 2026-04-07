import 'package:get/get.dart';

import '../../data/repositories/motchill_repository.dart';
import 'search_controller.dart';

class SearchBinding extends Bindings {
  @override
  void dependencies() {
    final parameters = Get.parameters;
    final initialLikedOnly =
        _boolParameter(parameters['likedOnly']) ||
        _boolParameter(parameters['favorite']) ||
        _boolParameter(parameters['mode'], expected: 'favorite');

    Get.lazyPut<SearchController>(
      () => SearchController(
        Get.find<MotchillRepository>(),
        initialLikedOnly: initialLikedOnly,
      ),
    );
  }
}

bool _boolParameter(String? value, {String expected = 'true'}) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return normalized == expected || normalized == '1';
}
