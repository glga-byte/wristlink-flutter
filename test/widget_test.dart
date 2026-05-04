import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/app/wristlink_app.dart';

void main() {
  testWidgets('renders the WristLink home screen', (tester) async {
    await tester.pumpWidget(const WristLinkApp());

    expect(find.text('WristLink'), findsWidgets);
    expect(
      find.text('Send useful data from your phone to Garmin watches.'),
      findsOneWidget,
    );
    expect(find.text('Points'), findsOneWidget);
    expect(find.text('Timers'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Send queue'), findsOneWidget);
  });
}
