import 'package:creador_cv/features/templates/cv_template_thumbnail.dart';
import 'package:creador_cv/features/templates/cv_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CvTemplateThumbnail construye todas las plantillas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final template in CvTemplates.all)
                  SizedBox(
                    height: 220,
                    child: CvTemplateThumbnail(
                      designIndex: template.designIndex,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byType(CvTemplateThumbnail),
      findsNWidgets(CvTemplates.all.length),
    );
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
