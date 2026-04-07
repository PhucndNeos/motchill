import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/network/motchill_api_client.dart';
import '../../data/repositories/motchill_repository.dart';
import '../../core/storage/liked_movie_store.dart';
import '../../features/player/playback_position_store.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<http.Client>(http.Client(), permanent: true);
    Get.put<MotchillApiClient>(
      MotchillApiClient(client: Get.find<http.Client>()),
      permanent: true,
    );
    Get.put<MotchillRepository>(
      MotchillRepository(apiClient: Get.find<MotchillApiClient>()),
      permanent: true,
    );
    Get.put<LikedMovieStore>(LikedMovieStore(), permanent: true);
    Get.put<PlaybackPositionStore>(PlaybackPositionStore(), permanent: true);
  }
}
