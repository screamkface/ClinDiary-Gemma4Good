import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/alerts/presentation/alerts_screen.dart';
import 'package:clindiary/features/auth/presentation/login_screen.dart';
import 'package:clindiary/features/auth/presentation/register_screen.dart';
import 'package:clindiary/features/auth/presentation/session_gate_screen.dart';
import 'package:clindiary/features/daily_journal/presentation/daily_check_in_screen.dart';
import 'package:clindiary/features/daily_journal/presentation/diary_screen.dart';
import 'package:clindiary/features/daily_journal/presentation/symptom_entry_screen.dart';
import 'package:clindiary/features/devices/presentation/devices_screen.dart';
import 'package:clindiary/features/debug/presentation/sync_debug_screen.dart';
import 'package:clindiary/features/dossier/presentation/health_dossier_screen.dart';
import 'package:clindiary/features/documents/presentation/document_detail_screen.dart';
import 'package:clindiary/features/documents/presentation/document_query_screen.dart';
import 'package:clindiary/features/documents/presentation/document_review_screen.dart';
import 'package:clindiary/features/documents/presentation/document_upload_screen.dart';
import 'package:clindiary/features/documents/presentation/documents_screen.dart';
import 'package:clindiary/features/history/presentation/history_screen.dart';
import 'package:clindiary/features/home/presentation/home_screen.dart';
import 'package:clindiary/features/insights/presentation/gemma_center_screen.dart';
import 'package:clindiary/features/insights/presentation/insights_screen.dart';
import 'package:clindiary/features/medications/presentation/medications_screen.dart';
import 'package:clindiary/features/notifications/presentation/notifications_screen.dart';
import 'package:clindiary/features/onboarding/presentation/onboarding_screen.dart';
import 'package:clindiary/features/prevention_center/presentation/prevention_center_screen.dart';
import 'package:clindiary/features/profile/presentation/clinical_episodes_screen.dart';
import 'package:clindiary/features/profile/presentation/family_profiles_screen.dart';
import 'package:clindiary/features/profile/presentation/profile_screen.dart';
import 'package:clindiary/features/profile/presentation/vaccination_history_screen.dart';
import 'package:clindiary/features/reports/presentation/reports_screen.dart';
import 'package:clindiary/features/screenings/presentation/screenings_screen.dart';
import 'package:clindiary/features/settings/presentation/app_settings_screen.dart';
import 'package:clindiary/features/settings/presentation/legal_center_screen.dart';
import 'package:clindiary/features/settings/presentation/legal_document_screen.dart';
import 'package:clindiary/features/settings/presentation/privacy_ai_screen.dart';
import 'package:clindiary/features/timeline/presentation/timeline_screen.dart';
import 'package:clindiary/features/wearables/presentation/wearables_screen.dart';
import 'package:clindiary/shared/widgets/root_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeBranchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _diaryBranchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'diary');
final _aiBranchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'ai');
final _documentsBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'documents',
);
final _profileBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'profile',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final appConfig = ref.read(appConfigProvider);
  final shouldBypassAuth =
      appConfig.hackathonDemoMode || appConfig.localOnlyMode;

  bool isPublicRoute(String location) {
    return location == '/' ||
        location == '/login' ||
        location == '/register' ||
        location.startsWith('/legal');
  }

  bool isAuthRoute(String location) {
    return location == '/login' || location == '/register';
  }

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final session = authState.valueOrNull;

      if (authState.isLoading) {
        return null;
      }

      if (shouldBypassAuth) {
        if (location == '/' ||
            isAuthRoute(location) ||
            location == '/onboarding') {
          return '/app/home';
        }
        return null;
      }

      if (session == null) {
        if (isPublicRoute(location)) {
          return null;
        }
        return '/login';
      }

      if (!session.user.onboardingCompleted) {
        if (location == '/onboarding' || isPublicRoute(location)) {
          return null;
        }
        return '/onboarding';
      }

      if (location == '/' ||
          isAuthRoute(location) ||
          location == '/onboarding') {
        return '/app/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SessionGateScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/legal',
        builder: (context, state) => const LegalCenterScreen(),
      ),
      GoRoute(
        path: '/legal/:document',
        builder: (context, state) {
          final document = LegalDocumentType.fromSlug(
            state.pathParameters['document'] ?? '',
          );
          if (document == null) {
            return const LegalCenterScreen();
          }
          return LegalDocumentScreen(documentType: document);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return RootShell(
            navigationShell: navigationShell,
            branchNavigatorKeys: [
              _homeBranchNavigatorKey,
              _diaryBranchNavigatorKey,
              _aiBranchNavigatorKey,
              _documentsBranchNavigatorKey,
              _profileBranchNavigatorKey,
            ],
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/app/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'insights',
                    builder: (context, state) => const InsightsScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const HistoryScreen(),
                  ),
                  GoRoute(
                    path: 'timeline',
                    builder: (context, state) => const TimelineScreen(),
                  ),
                  GoRoute(
                    path: 'alerts',
                    builder: (context, state) => const AlertsScreen(),
                  ),
                  GoRoute(
                    path: 'prevention-center',
                    builder: (context, state) => const PreventionCenterScreen(),
                  ),
                  GoRoute(
                    path: 'dossier',
                    builder: (context, state) => const HealthDossierScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'screenings',
                    builder: (context, state) => const ScreeningsScreen(),
                  ),
                  GoRoute(
                    path: 'medications',
                    builder: (context, state) => const MedicationsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                  GoRoute(
                    path: 'wearables',
                    builder: (context, state) => const WearablesScreen(),
                  ),
                  GoRoute(
                    path: 'devices',
                    builder: (context, state) => const DevicesScreen(),
                  ),
                  GoRoute(
                    path: 'sync-debug',
                    builder: (context, state) => const SyncDebugScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _diaryBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/app/diary',
                builder: (context, state) => const DiaryScreen(),
                routes: [
                  GoRoute(
                    path: 'check-up',
                    builder: (context, state) => const DailyCheckInScreen(),
                  ),
                  GoRoute(
                    path: ':entryId/symptom',
                    builder: (context, state) => SymptomEntryScreen(
                      entryId: state.pathParameters['entryId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _aiBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/app/ai',
                builder: (context, state) => GemmaCenterScreen(
                  initialQuestion: state.uri.queryParameters['question'],
                  documentId: state.uri.queryParameters['documentId'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _documentsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/app/documents',
                builder: (context, state) => const DocumentsScreen(),
                routes: [
                  GoRoute(
                    path: 'ask',
                    builder: (context, state) => DocumentQueryScreen(
                      initialFolderId: state.uri.queryParameters['folderId'],
                      initialFolderName:
                          state.uri.queryParameters['folderName'],
                    ),
                  ),
                  GoRoute(
                    path: 'upload',
                    builder: (context, state) => DocumentUploadScreen(
                      initialFolderId: state.uri.queryParameters['folderId'],
                      initialFolderName:
                          state.uri.queryParameters['folderName'],
                      initialStorageLocation:
                          state.uri.queryParameters['storageMode'],
                    ),
                  ),
                  GoRoute(
                    path: ':documentId',
                    builder: (context, state) => DocumentDetailScreen(
                      documentId: state.pathParameters['documentId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'review',
                        builder: (context, state) => DocumentReviewScreen(
                          documentId: state.pathParameters['documentId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/app/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'family',
                    builder: (context, state) => const FamilyProfilesScreen(),
                  ),
                  GoRoute(
                    path: 'problems',
                    builder: (context, state) => const ClinicalEpisodesScreen(),
                  ),
                  GoRoute(
                    path: 'vaccinations',
                    builder: (context, state) =>
                        const VaccinationHistoryScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const AppSettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'privacy-ai',
                        builder: (context, state) => const PrivacyAiScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text(state.error.toString()))),
  );
});
