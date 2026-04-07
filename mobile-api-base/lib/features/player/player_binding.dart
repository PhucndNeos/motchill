import 'package:get/get.dart';

import '../../data/repositories/motchill_repository.dart';
import 'player_controller.dart';

class PlayerBinding extends Bindings {
  @override
  void dependencies() {
    final movieId = int.tryParse(Get.parameters['movieId'] ?? '') ?? 0;
    final episodeId = int.tryParse(Get.parameters['episodeId'] ?? '') ?? 0;
    final args = Get.arguments;
    final movieTitle = args is Map ? '${args['movieTitle'] ?? ''}' : '';
    final episodeLabel = args is Map ? '${args['episodeLabel'] ?? ''}' : '';

    Get.lazyPut<PlayerController>(
      () => PlayerController(
        Get.find<MotchillRepository>(),
        movieId: movieId,
        episodeId: episodeId,
        movieTitle: movieTitle,
        episodeLabel: episodeLabel,
      ),
    );
  }
}
