import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/data/app_database.dart';
import 'package:downlink/src/providers.dart';
import 'package:downlink/src/ui/home_shell.dart';

void main() {
  testWidgets('uses bottom navigation on narrow screens', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith((ref) async {}),
          downloadsProvider.overrideWith(
            (ref) => Stream<List<DownloadEntity>>.value(const []),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: HomeShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses navigation rail on wide screens', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith((ref) async {}),
          downloadsProvider.overrideWith(
            (ref) => Stream<List<DownloadEntity>>.value(const []),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(1200, 800)),
            child: HomeShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
