import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/features/design_system/design_gallery_page.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App boots to the single login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DongaApp()));
    await tester.pumpAndSettle();

    // Unauthenticated users land directly on the single login form
    // (no student/admin gateway). Role branching happens after login.
    expect(find.text('계정 정보를 입력해 주세요.'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
  });

  testWidgets('Design gallery is reachable at /design', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    router.go('/design');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesignGalleryPage), findsOneWidget);
  });
}
