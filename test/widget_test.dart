import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:college_event_manager/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Note: Firebase.initializeApp() usually fails in unit tests 
    // without mock setup. For a simple build test, we can pump the app.
    
    await tester.pumpWidget(const CampuslyApp());

    expect(find.byType(CampuslyApp), findsOneWidget);
  });
}
