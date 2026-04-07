import 'package:get/get.dart';

import '../../data/repositories/motchill_repository.dart';
import 'detail_controller.dart';

class DetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DetailController>(
      () => DetailController(
        Get.find<MotchillRepository>(),
        slug: Get.parameters['slug'] ?? '',
      ),
    );
  }
}
