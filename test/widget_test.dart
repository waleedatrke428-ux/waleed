import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/main.dart';

void main() {
  testWidgets('renders the futures signal entry form', (tester) async {
    await tester.pumpWidget(const SignalAdminApp());

    expect(find.text('كربيتو البلحوسي'), findsOneWidget);
    expect(find.text('بيانات الصفقة الأساسية'), findsOneWidget);
    expect(find.text('رمز التداول (Symbol)'), findsOneWidget);
  });
}
