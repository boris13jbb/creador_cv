import 'package:creador_cv/features/templates/cv_template_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CvTemplateThumbnail construye las 4 plantillas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                    height: 220,
                    child: CvTemplateThumbnail(designIndex: i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CvTemplateThumbnail), findsNWidgets(4));
  });

  testWidgets('CvTemplateThumbnail locked muestra candado', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: CvTemplateThumbnail(designIndex: 2, locked: true),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
