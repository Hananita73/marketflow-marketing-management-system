// Basic smoke test for the Marketing Management System.
//
// Verifies that the LoginScreen renders correctly with all expected elements.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:marketing_management_system/screens/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders all expected elements', (WidgetTester tester) async {
    // Use a wide enough surface to avoid the pre-existing
    // "Remember me" row overflow on narrow test viewports.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );
    await tester.pumpAndSettle();

    // Brand header — "MarketFlow" appears in both branding panel and form
    expect(find.text('MarketFlow'), findsWidgets);
    expect(find.text('Marketing Management System'), findsWidgets);

    // Welcome text
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Sign in to continue to your Marketing Management System.'),
      findsOneWidget,
    );

    // Form fields
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Sign-in button
    expect(find.text('Sign In'), findsOneWidget);

    // Sign-up prompt
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('Create one'), findsOneWidget);
  });
}
