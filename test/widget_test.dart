import 'package:flutter_test/flutter_test.dart';
import 'package:mahnegar/main.dart';

void main() {
  testWidgets('MahNegar app renders', (tester) async {
    await tester.pumpWidget(const MahNegarApp());
    expect(find.text('ماه‌نگار'), findsOneWidget);
  });
}
