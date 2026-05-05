import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/app/wristlink_app.dart';

void main() {
  testWidgets('renders the primary tab scaffold and initial Send destination', (
    tester,
  ) async {
    await tester.pumpWidget(const WristLinkApp());

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Send to watch'), findsOneWidget);
    expect(find.text('Share a place from Maps'), findsOneWidget);
    expect(find.text('Manual point'), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Command'), 120);

    expect(find.text('Command'), findsOneWidget);
  });

  testWidgets('switches between primary tab destinations', (tester) async {
    await tester.pumpWidget(const WristLinkApp());

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    expect(find.text('ALL PROGRESS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('queued'), findsNWidgets(2));
    expect(find.text('sending'), findsOneWidget);
    expect(find.text('failed'), findsNWidgets(2));
    expect(find.text('delivered'), findsOneWidget);
    expect(find.text('Trailhead parking'), findsOneWidget);
    expect(find.text('Coffee meet point'), findsOneWidget);
    expect(find.text('Home note'), findsOneWidget);
    expect(find.text('Gym timer'), findsOneWidget);

    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();

    expect(find.text('GARMIN CONNECT IQ'), findsOneWidget);
    expect(find.text('connected'), findsOneWidget);
    expect(find.text('setup'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(find.text('Forerunner 965'), findsOneWidget);
    expect(find.text('Fenix 7'), findsOneWidget);
    expect(find.text('Venu 3'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('WRISTLINK'), findsOneWidget);
    expect(find.text('Default watch'), findsOneWidget);
    expect(find.text('Background sending'), findsOneWidget);
    expect(find.text('About WristLink'), findsOneWidget);
  });
}
