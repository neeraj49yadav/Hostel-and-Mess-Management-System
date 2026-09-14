import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App smoke test loads PIN screen', (WidgetTester tester) async {
    expect(find.byType(HostelMessAdminApp), findsOneWidget);
  });
}
