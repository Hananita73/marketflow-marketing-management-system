import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketing_management_system/utils/input_validators.dart';
import 'package:marketing_management_system/widgets/common/custom_textfield.dart';

void main() {
  group('InputValidators.email', () {
    test('accepts valid email addresses', () {
      expect(InputValidators.email('person@example.com'), isNull);
      expect(InputValidators.email('first.last+tag@sub.example.et'), isNull);
    });

    test('rejects malformed or oversized addresses', () {
      expect(InputValidators.email('person@example'), isNotNull);
      expect(InputValidators.email('person @example.com'), isNotNull);
      expect(
        InputValidators.email('${List.filled(250, 'a').join()}@example.com'),
        isNotNull,
      );
      expect(InputValidators.email(''), isNotNull);
      expect(InputValidators.email('', required: false), isNull);
    });
  });

  group('InputValidators.ethiopianPhone', () {
    test('accepts local Ethio telecom and Safaricom mobile formats', () {
      expect(InputValidators.ethiopianPhone('0911 234 567'), isNull);
      expect(InputValidators.ethiopianPhone('0711-234-567'), isNull);
    });

    test('accepts international country-code formats', () {
      expect(InputValidators.ethiopianPhone('+251 911 234 567'), isNull);
      expect(InputValidators.ethiopianPhone('+251 711 234 567'), isNull);
    });

    test('rejects invalid prefixes, lengths, and non-numeric input', () {
      expect(InputValidators.ethiopianPhone('0611 234 567'), isNotNull);
      expect(InputValidators.ethiopianPhone('0911 234 56'), isNotNull);
      expect(InputValidators.ethiopianPhone('0911 234 5678'), isNotNull);
      expect(InputValidators.ethiopianPhone(''), isNotNull);
      expect(InputValidators.ethiopianPhone('', required: false), isNull);
    });
  });

  testWidgets('CustomTextField validates as the user types', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          child: CustomTextField(
            controller: controller,
            validator: InputValidators.email,
          ),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'person@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsNothing);
  });
}
