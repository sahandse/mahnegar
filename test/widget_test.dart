import 'package:flutter_test/flutter_test.dart';
import 'package:mahnegar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MahNegar app renders', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MahNegarApp());
    await tester.pump();
    expect(find.text('ماه‌نگار'), findsOneWidget);
  });
}
