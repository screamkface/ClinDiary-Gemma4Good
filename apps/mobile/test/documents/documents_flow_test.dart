import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/data/document_picker_service.dart';
import 'package:clindiary/features/documents/data/documents_repository.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_manual_review.dart';
import 'package:clindiary/features/documents/presentation/document_detail_screen.dart';
import 'package:clindiary/features/documents/presentation/document_query_screen.dart';
import 'package:clindiary/features/documents/presentation/document_review_screen.dart';
import 'package:clindiary/features/documents/presentation/document_upload_screen.dart';
import 'package:clindiary/features/documents/presentation/documents_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockDocumentsRepository extends Mock implements DocumentsRepository {}

class MockDocumentPickerService extends Mock implements DocumentPickerService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
    registerFallbackValue(
      const SelectedUploadDocument(
        name: 'fallback.pdf',
        bytes: [1, 2, 3],
        mimeType: 'application/pdf',
      ),
    );
    registerFallbackValue(<String, String>{});
    registerFallbackValue(
      const DocumentManualReviewInput(documentType: 'generic_document'),
    );
  });

  testWidgets('documents screen mostra elenco e stati documentali', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentArchiveProvider.overrideWith(
            (ref, query) async => DocumentArchiveView(
              breadcrumbs: const [],
              folders: const [
                DocumentFolderItem(
                  id: 'folder-1',
                  name: 'Esami',
                  pathLabel: 'Esami',
                  childFolderCount: 0,
                  documentCount: 1,
                ),
              ],
              documents: [
                ClinicalDocumentSummary(
                  id: 'doc-1',
                  title: 'Esami marzo',
                  documentType: 'lab_report',
                  uploadDate: DateTime.utc(2026, 3, 20, 8),
                  originalFilename: 'esami-marzo.pdf',
                  mimeType: 'application/pdf',
                  fileSizeBytes: 182400,
                  parsedStatus: 'parsed',
                  contextStatus: 'old',
                  processingError: null,
                  pendingSync: true,
                ),
              ],
              isSearch: false,
            ),
          ),
        ],
        child: const MaterialApp(home: DocumentsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Esami marzo'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Esami marzo'), findsOneWidget);
    expect(find.text('Esami'), findsOneWidget);
    expect(find.textContaining('Lab report'), findsOneWidget);
    expect(find.text('Parsed'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('Sync pending'), findsOneWidget);
    expect(find.textContaining('Waiting for sync'), findsOneWidget);
    expect(find.textContaining('178.1 KB'), findsOneWidget);
  });

  testWidgets('documents screen crea una cartella senza eccezioni Flutter', (
    tester,
  ) async {
    final repository = MockDocumentsRepository();

    when(
      () => repository.createFolder(
        name: any(named: 'name'),
        parentFolderId: any(named: 'parentFolderId'),
      ),
    ).thenAnswer(
      (_) async => const DocumentFolderItem(
        id: 'folder-2',
        name: 'Esami sangue',
        pathLabel: 'Esami sangue',
        childFolderCount: 0,
        documentCount: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWith((ref) => repository),
          documentArchiveProvider.overrideWith(
            (ref, query) async => const DocumentArchiveView(
              breadcrumbs: [],
              folders: [],
              documents: [],
              isSearch: false,
            ),
          ),
        ],
        child: const MaterialApp(home: DocumentsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Folder name'),
      'Esami sangue',
    );

    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    verify(
      () => repository.createFolder(name: 'Esami sangue', parentFolderId: null),
    ).called(1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'documents screen apre sposta file dal menu senza errori navigator',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentArchiveProvider.overrideWith(
              (ref, query) async => DocumentArchiveView(
                breadcrumbs: const [],
                folders: const [],
                documents: [
                  ClinicalDocumentSummary(
                    id: 'doc-1',
                    title: 'Esami marzo',
                    documentType: 'lab_report',
                    uploadDate: DateTime.utc(2026, 3, 20, 8),
                    originalFilename: 'esami-marzo.pdf',
                    mimeType: 'application/pdf',
                    fileSizeBytes: 182400,
                    parsedStatus: 'parsed',
                    processingError: null,
                  ),
                ],
                isSearch: false,
              ),
            ),
            documentFoldersProvider.overrideWith(
              (ref) async => const [
                DocumentFolderItem(
                  id: 'folder-1',
                  name: 'Esami 2026',
                  pathLabel: 'Esami 2026',
                  childFolderCount: 0,
                  documentCount: 1,
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: DocumentsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Parsed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move file').last);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Main archive'), findsOneWidget);
      expect(find.text('Esami 2026'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'document detail screen nasconde il testo estratto finché l’utente non lo apre',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentDetailProvider.overrideWith(
              (ref, documentId) async => ClinicalDocumentDetail(
                id: documentId,
                title: 'Referto laboratorio aprile',
                documentType: 'lab_report',
                uploadDate: DateTime.utc(2026, 4, 2, 9),
                examDate: DateTime.utc(2026, 4, 1),
                source: 'Laboratorio locale',
                originalFilename: 'lab-aprile.pdf',
                mimeType: 'application/pdf',
                fileSizeBytes: 64000,
                parsedStatus: 'parsed',
                contextStatus: 'old',
                classificationConfidence: 0.91,
                parsingConfidence: 0.84,
                processingError: null,
                pendingSync: true,
                fileUrl: 'patients/demo/lab-aprile.pdf',
                viewerUrl: '/api/v1/documents/doc-1/content?token=abc',
                ocrText: 'Glucosio 110 mg/dL 70-99',
                processedAt: DateTime.utc(2026, 4, 2, 9, 5),
                labPanels: const [
                  LabPanelItem(
                    id: 'panel-1',
                    panelName: 'Esami del sangue',
                    results: [
                      LabResultItem(
                        id: 'result-1',
                        analyteName: 'Glucosio',
                        value: '110',
                        unit: 'mg/dL',
                        refMin: 70,
                        refMax: 99,
                        abnormalFlag: true,
                      ),
                    ],
                  ),
                ],
                imagingReports: const [],
              ),
            ),
          ],
          child: const MaterialApp(
            home: DocumentDetailScreen(documentId: 'doc-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Referto laboratorio aprile'), findsOneWidget);
      expect(find.text('Sync pending'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(find.text('Extracted text'), findsOneWidget);
      expect(find.text('Show text'), findsOneWidget);
      expect(find.textContaining('Glucosio 110 mg/dL 70-99'), findsNothing);
      await tester.tap(find.text('Show text'));
      await tester.pumpAndSettle();
      expect(find.text('Hide text'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(find.textContaining('Glucosio'), findsWidgets);
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pumpAndSettle();
      final abnormalValueText = tester.widget<Text>(find.text('110 mg/dL'));
      final context = tester.element(find.text('110 mg/dL'));
      expect(find.text('Out of range'), findsOneWidget);
      expect(
        abnormalValueText.style?.color,
        equals(Theme.of(context).colorScheme.error),
      );
      expect(find.text('Old'), findsWidgets);
      expect(find.textContaining('not included in AI recaps'), findsOneWidget);
      expect(find.textContaining('changes waiting to sync'), findsOneWidget);
      expect(find.text('Open file'), findsOneWidget);
      expect(find.text('Manual review'), findsOneWidget);
    },
  );

  testWidgets(
    'document detail screen apre sposta file dal menu senza errori navigator',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentFoldersProvider.overrideWith(
              (ref) async => const [
                DocumentFolderItem(
                  id: 'folder-1',
                  name: 'Esami 2026',
                  pathLabel: 'Esami 2026',
                  childFolderCount: 0,
                  documentCount: 1,
                ),
              ],
            ),
            documentDetailProvider.overrideWith(
              (ref, documentId) async => ClinicalDocumentDetail(
                id: documentId,
                title: 'Referto laboratorio aprile',
                documentType: 'lab_report',
                uploadDate: DateTime.utc(2026, 4, 2, 9),
                examDate: DateTime.utc(2026, 4, 1),
                source: 'Laboratorio locale',
                originalFilename: 'lab-aprile.pdf',
                mimeType: 'application/pdf',
                fileSizeBytes: 64000,
                parsedStatus: 'parsed',
                contextStatus: 'active',
                classificationConfidence: 0.91,
                parsingConfidence: 0.84,
                processingError: null,
                pendingSync: false,
                fileUrl: 'patients/demo/lab-aprile.pdf',
                viewerUrl: '/api/v1/documents/doc-1/content?token=abc',
                ocrText: 'Glucosio 110 mg/dL 70-99',
                processedAt: DateTime.utc(2026, 4, 2, 9, 5),
                labPanels: const [],
                imagingReports: const [],
              ),
            ),
          ],
          child: const MaterialApp(
            home: DocumentDetailScreen(documentId: 'doc-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move file').last);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Main archive'), findsOneWidget);
      expect(find.text('Esami 2026'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'document upload screen seleziona file, invia upload e naviga al dettaglio',
    (tester) async {
      final repository = MockDocumentsRepository();
      final picker = MockDocumentPickerService();

      when(() => picker.pickDocument()).thenAnswer(
        (_) async => const SelectedUploadDocument(
          name: 'nuovo-referto.pdf',
          bytes: [37, 80, 68, 70],
          mimeType: 'application/pdf',
        ),
      );
      when(
        () => repository.uploadDocument(
          file: any(named: 'file'),
          fields: any(named: 'fields'),
        ),
      ).thenAnswer(
        (_) async => ClinicalDocumentSummary(
          id: 'doc-42',
          title: 'Nuovo referto',
          documentType: 'generic_document',
          uploadDate: DateTime.utc(2026, 3, 20, 10),
          originalFilename: 'nuovo-referto.pdf',
          mimeType: 'application/pdf',
          fileSizeBytes: 4096,
          parsedStatus: 'pending',
          processingError: null,
        ),
      );

      final router = GoRouter(
        initialLocation: '/app/documents/upload',
        routes: [
          GoRoute(
            path: '/app/documents/upload',
            builder: (_, __) => const DocumentUploadScreen(),
          ),
          GoRoute(
            path: '/app/documents/:documentId',
            builder: (_, state) => Scaffold(
              body: Text('Dettaglio ${state.pathParameters['documentId']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsRepositoryProvider.overrideWith((ref) => repository),
            documentPickerServiceProvider.overrideWith((ref) => picker),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.tap(find.text('Select file'));
      await tester.pumpAndSettle();
      expect(find.text('nuovo-referto.pdf'), findsOneWidget);
      verify(() => picker.pickDocument()).called(1);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Document title'),
        'Nuovo referto',
      );
      await tester.scrollUntilVisible(
        find.byIcon(Icons.cloud_upload_outlined),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byIcon(Icons.cloud_upload_outlined));
      await tester.pumpAndSettle();

      verify(
        () => repository.uploadDocument(
          file: any(named: 'file'),
          fields: any(named: 'fields'),
        ),
      ).called(1);
    },
  );

  testWidgets('document query screen mostra risposta e citazioni', (
    tester,
  ) async {
    final repository = MockDocumentsRepository();

    when(
      () => repository.queryDocuments(
        question: any(named: 'question'),
        folderId: any(named: 'folderId'),
        topK: any(named: 'topK'),
      ),
    ).thenAnswer(
      (_) async => DocumentQueryResult(
        answer:
            'Referti recenti: la creatinina risulta elevata in un documento recente [1].',
        citations: const [
          DocumentQueryCitation(
            documentId: 'doc-42',
            documentTitle: 'Esami aprile',
            documentType: 'lab_report',
            folderName: 'Esami 2026',
            chunkKind: 'lab_panel',
            chunkLabel: 'Pannello laboratorio',
            excerpt: 'Creatinina: 1.6 mg/dL range 0.7-1.2 fuori range',
            score: 0.92,
          ),
        ],
        providerName: 'regolo_ai',
        modelName: 'qwen3-8b',
        embeddingModelName: 'qwen3-embedding-8b',
        rerankerModelName: 'qwen3-reranker-4b',
        retrievedChunks: 1,
        retrievedDocuments: 1,
        searchScopeLabel: 'Cartella: Esami',
        coverageNote: '1 documento e 1 passaggio usati per la risposta.',
        usedFallback: false,
      ),
    );
    when(() => repository.reindexDocuments()).thenAnswer((_) async => 3);

    final router = GoRouter(
      initialLocation: '/app/documents/ask?folderId=folder-1&folderName=Esami',
      routes: [
        GoRoute(
          path: '/app/documents/ask',
          builder: (_, state) => DocumentQueryScreen(
            initialFolderId: state.uri.queryParameters['folderId'],
            initialFolderName: state.uri.queryParameters['folderName'],
          ),
        ),
        GoRoute(
          path: '/app/documents/:documentId',
          builder: (_, state) => Scaffold(
            body: Text('Dettaglio ${state.pathParameters['documentId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Esami'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Ci sono valori fuori range?',
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search files'), warnIfMissed: false);
    await tester.pumpAndSettle();

    verify(
      () => repository.queryDocuments(
        question: 'Ci sono valori fuori range?',
        folderId: 'folder-1',
        topK: null,
      ),
    ).called(1);
    expect(find.textContaining('creatinina risulta elevata'), findsOneWidget);
    expect(find.textContaining('1 documento e 1 passaggio'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Esami aprile'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Esami aprile'), findsOneWidget);
    expect(find.textContaining('qwen3-reranker-4b'), findsOneWidget);

    await tester.tap(find.text('Refresh index'), warnIfMissed: false);
    await tester.pump();
    verify(() => repository.reindexDocuments()).called(1);
  });

  testWidgets(
    'document review screen invia revisione manuale e chiude la schermata',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final repository = MockDocumentsRepository();

      when(() => repository.submitManualReview(any(), any())).thenAnswer(
        (_) async => ClinicalDocumentDetail(
          id: 'doc-9',
          title: 'Referto revisionato',
          documentType: 'generic_document',
          uploadDate: DateTime.utc(2026, 3, 20, 10),
          examDate: DateTime.utc(2026, 3, 19),
          source: 'Laboratorio locale',
          originalFilename: 'scan.png',
          mimeType: 'image/png',
          fileSizeBytes: 4096,
          parsedStatus: 'reviewed',
          classificationConfidence: 1,
          parsingConfidence: 1,
          processingError: null,
          fileUrl: 'patients/demo/scan.png',
          viewerUrl: '/api/v1/documents/doc-9/content?token=abc',
          ocrText: 'Glucosio 102 mg/dL 70-99',
          processedAt: DateTime.utc(2026, 3, 20, 10, 10),
          labPanels: const [],
          imagingReports: const [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsRepositoryProvider.overrideWith((ref) => repository),
            documentDetailProvider.overrideWith(
              (ref, documentId) async => ClinicalDocumentDetail(
                id: documentId,
                title: 'Scan da correggere',
                documentType: 'generic_document',
                uploadDate: DateTime.utc(2026, 3, 20, 8),
                examDate: DateTime.utc(2026, 3, 19),
                source: 'Laboratorio locale',
                originalFilename: 'scan.png',
                mimeType: 'image/png',
                fileSizeBytes: 5120,
                parsedStatus: 'review_required',
                classificationConfidence: 0.4,
                parsingConfidence: null,
                processingError: 'Servono correzioni manuali',
                fileUrl: 'patients/demo/scan.png',
                viewerUrl: '/api/v1/documents/doc-9/content?token=abc',
                ocrText: 'Glucosio 102 mg/dL 70-99',
                processedAt: DateTime.utc(2026, 3, 20, 8, 30),
                labPanels: const [],
                imagingReports: const [],
              ),
            ),
          ],
          child: const MaterialApp(
            home: DocumentReviewScreen(documentId: 'doc-9'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Referto revisionato');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final saveLabel = find.text('Save manual review');
      expect(saveLabel, findsOneWidget);
      await tester.ensureVisible(saveLabel);
      final saveButton = find.ancestor(
        of: saveLabel,
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      await tester.tap(saveButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      verify(() => repository.submitManualReview('doc-9', any())).called(1);
    },
  );
}
