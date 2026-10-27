import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suga/services/api_client.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/widgets/ui.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: buildSugaTheme(), home: Scaffold(body: child));

void main() {
  group('ErrorPanel', () {
    testWidgets('offline says so and offers Retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_wrap(ErrorPanel(
        what: 'areas',
        error: const ApiException('Could not reach the server. Check your connection.',
            kind: ApiErrorKind.offline),
        onRetry: () => retried++,
      )));

      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Could not reach the server. Check your connection.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('a timeout has its own title', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorPanel(
        what: 'areas',
        error: ApiException('Try again in a moment.', kind: ApiErrorKind.timeout),
      )));

      expect(find.text('SUGA is taking too long to respond'), findsOneWidget);
      expect(find.text('Retry'), findsNothing, reason: 'no retry callback was given');
    });

    testWidgets('a server error names what failed to load', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorPanel(
        what: 'brownouts',
        error: ApiException('Something went wrong', statusCode: 500, kind: ApiErrorKind.server),
      )));

      expect(find.text("Couldn't load brownouts"), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('an unexpected exception shows a generic message, not its text', (tester) async {
      await tester.pumpWidget(_wrap(ErrorPanel(what: 'areas', error: StateError('boom'))));

      expect(find.textContaining('boom'), findsNothing);
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    });
  });

  testWidgets('InlineNotice shows its message and action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(InlineNotice(
      message: "Couldn't refresh.",
      actionLabel: 'Retry',
      onAction: () => taps++,
    )));

    expect(find.text("Couldn't refresh."), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(taps, 1);
  });
}
