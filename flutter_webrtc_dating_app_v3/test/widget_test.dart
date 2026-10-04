import 'package:availchat/models/question_model.dart';
import 'package:availchat/models/question_type.dart';
import 'package:availchat/screens/questionnaire/widgets/question_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parent that stores every answer and rebuilds, like the questionnaire screen.
class _Host extends StatefulWidget {
  const _Host({required this.question, this.initial});

  final Question question;
  final dynamic initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late dynamic answer = widget.initial;

  void setExternal(dynamic value) => setState(() => answer = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuestionWidget(
            question: widget.question,
            answer: answer,
            onAnswerChanged: (v) => setState(() => answer = v),
          ),
        ),
      ),
    );
  }
}

void main() {
  const textQ = Question(
    text: 'Your bio',
    inputType: QuestionType.text,
    fieldName: 'bio',
  );
  const multiQ = Question(
    text: 'Pets',
    inputType: QuestionType.multiChoice,
    fieldName: 'pets',
    options: ['Dog', 'Cat', 'Fish'],
  );

  TextEditingController controllerOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;

  testWidgets('text answer keeps its controller and cursor (DEST-031)', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(question: textQ));
    final controller = controllerOf(tester);

    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.pump();
    controller.selection = const TextSelection.collapsed(offset: 2);

    // Parent rebuilds with the same answer it just received.
    tester.state<_HostState>(find.byType(_Host)).setExternal('Hello there');
    await tester.pump();

    expect(controllerOf(tester), same(controller));
    expect(controller.text, 'Hello there');
    expect(controller.selection.baseOffset, 2);
  });

  testWidgets('answer loaded after build replaces the text', (tester) async {
    await tester.pumpWidget(const _Host(question: textQ));
    tester.state<_HostState>(find.byType(_Host)).setExternal('From server');
    await tester.pump();

    final controller = controllerOf(tester);
    expect(controller.text, 'From server');
    expect(controller.selection.baseOffset, 'From server'.length);
  });

  testWidgets('multi-choice accepts List<dynamic> from Firestore (DEST-032)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Host(question: multiQ, initial: <dynamic>['Cat', null]),
    );

    FilterChip chip(String label) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
    expect(chip('Cat').selected, isTrue);
    expect(chip('Dog').selected, isFalse);

    await tester.tap(find.text('Dog'));
    await tester.pump();
    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.answer, ['Cat', 'Dog']);
  });

  testWidgets('multi-choice accepts a legacy single string', (tester) async {
    await tester.pumpWidget(const _Host(question: multiQ, initial: 'Fish'));
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Fish'))
          .selected,
      isTrue,
    );
  });
}
