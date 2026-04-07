import 'package:get/get.dart';

import '../../data/models/motchill_models.dart';
import '../../data/repositories/motchill_repository.dart';

class HomeController extends GetxController {
  HomeController(this._repository);

  final MotchillRepository _repository;

  final sections = <HomeSection>[].obs;
  final popupAd = Rxn<PopupAdConfig>();
  final isLoading = true.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final results = await Future.wait([
        _repository.loadHome(),
        _repository.loadPopupAd(),
      ]);

      sections.assignAll(results[0] as List<HomeSection>);
      popupAd.value = results[1] as PopupAdConfig?;
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => load();
}
