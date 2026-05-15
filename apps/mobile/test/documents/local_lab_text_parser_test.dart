import 'package:clindiary/features/documents/data/local_lab_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parser = LocalLabTextParser();

  test('local parser ignores demographic metadata in lab reports', () async {
    const reportText = '''
Date of Birth 01 January
Patient ID: MR-2026-041
Address: Via Roma 123 Milan
Report Date 20 April
Hemoglobin 14.5 g/dL 13.5 - 17.5
Hematocrit 43 % 40.0 - 52.0
Red Blood Cells 4.9 4.2 - 5.9
''';

    final parsed = await parser.parse(
      documentId: 'lab-doc-1',
      documentType: 'lab_report',
      title: 'April labs',
      text: reportText,
    );

    expect(parsed.parsedStatus, 'parsed');
    expect(parsed.labPanels, hasLength(1));

    final analytes = parsed.labPanels.single.results
        .map((result) => result.analyteName)
        .toList(growable: false);

    expect(analytes, contains('Hemoglobin'));
    expect(analytes, contains('Hematocrit'));
    expect(analytes, contains('Red Blood Cells'));
    expect(analytes, isNot(contains('Date of Birth')));
    expect(analytes, isNot(contains('Patient ID')));
    expect(analytes, isNot(contains('Address')));
    expect(analytes, isNot(contains('Report Date')));
  });

  test('local parser splits dense PDF table text into lab rows', () async {
    const reportText =
        'Esame Risultato Unita Valori di riferimento '
        'Glicemia 109 mg/dL 70 - 100 '
        'Colesterolo LDL 138 mg/dL < 115 '
        'Emoglobina 13,4 g/dL 12,0 - 16,0';

    final parsed = await parser.parse(
      documentId: 'lab-doc-2',
      documentType: 'generic_document',
      title: 'Blood results uploaded from PDF',
      text: reportText,
    );

    expect(parsed.parsedStatus, 'parsed');
    final results = parsed.labPanels.single.results;
    expect(results.map((item) => item.analyteName), contains('Glicemia'));
    expect(
      results.map((item) => item.analyteName),
      contains('Colesterolo LDL'),
    );
    expect(results.map((item) => item.analyteName), contains('Emoglobina'));

    final ldl = results.firstWhere(
      (item) => item.analyteName == 'Colesterolo LDL',
    );
    expect(ldl.abnormalFlag, isTrue);
  });

  test(
    'local parser infers lab report type from generic blood result uploads',
    () {
      final inferred = parser.inferDocumentType(
        documentType: 'generic_document',
        title: 'blood-results.pdf',
        text: 'Glicemia 109 mg/dL 70 - 100',
      );

      expect(inferred, 'lab_report');
    },
  );
}
