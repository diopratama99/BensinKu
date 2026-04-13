// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:bensinku/app/app.dart';
import 'package:bensinku/config/app_config.dart';

void main() {
  testWidgets('Shows config screen when Supabase is missing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const BensinKuApp(
        config: AppConfig(supabaseUrl: null, supabaseAnonKey: null),
        supabaseReady: false,
      ),
    );

    expect(find.text('Supabase belum dikonfigurasi.'), findsOneWidget);
  });
}
