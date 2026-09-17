import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safescan_frontend/screens/splash_screen.dart';
import 'package:safescan_frontend/theme/app_theme.dart';

void main() {
  testWidgets('SplashScreen renders logo, brand title, and loading status message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );

    // Initial frame
    expect(find.text('SafeScan'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Loading security services'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });
}
