import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/src/api.dart';
import 'package:mobile/src/data/motchill_repository.dart';
import 'package:mobile/src/models.dart';
import 'package:mobile/src/screens/home_screen.dart';

class _FakeApi extends MotchillApi {
  _FakeApi();

  @override
  Future<List<MovieCard>> fetchHome() async => const [
        MovieCard(
          slug: 'demo-slug',
          title: 'Demo Movie',
          subtitle: 'Subtitle',
          image: '',
          href: 'https://example.com/demo',
          badge: 'HD',
        ),
      ];
}

void main() {
  testWidgets('home screen renders content', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: MotchillRepository.fromApi(_FakeApi())),
      ),
    );
    await tester.pump();
    expect(find.text('Motchill'), findsOneWidget);
    expect(find.text('Demo Movie'), findsOneWidget);
  });
}
