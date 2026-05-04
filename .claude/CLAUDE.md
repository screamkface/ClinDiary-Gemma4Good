# ClinDiary

## WHY
ClinDiary is a resilient, private, local-first clinical diary mobile application. It captures health events (symptoms, vitals, documents) and uses deterministic engines for safety-critical clinical logic. Its hero feature is an entirely on-device AI summary generator (Gemma 4 via LiteRT-LM) to provide private daily recaps without relying on external cloud backends.

## WHAT 
This is a Flutter-based application following a feature-first architecture. 
- **Main App Path**: `apps/mobile/`
- **Architecture**: `lib/features/<feature-name>/` (divided into `data/`, `domain/`, and `presentation/`).
- **Stack**: Flutter (3.35+), Riverpod (DI and State), GoRouter (routing), Drift (local SQLite persistence), LiteRT-LM (Android on-device ML inference).
- All core workflows, including queue-based jobs (like OCR and parsing) and data storage, reside and execute locally on the device constraints.

## HOW
- **Build & Run**: Always prefer the repository scripts over raw flutter commands to ensure local infra dependencies are correctly wired.
  - Windows: `powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1`
  - Linux/Mac: `bash scripts/run_android_app.sh`
- **Testing**: Run tests via `flutter test` within the `apps/mobile/` directory.

## PROGRESSIVE DISCLOSURE (READ BEFORE ACTING)
Do not guess how systems are implemented. If working on specific domains, please consult the relevant documentation first:
- **Project Status & Arch**: See `docs/architecture/project-architecture-overview.md` and `docs/architecture/actual-situation.md`.
- **API & Phases**: Detailed historical implementations are tracked in `docs/api/`.
- **Hackathon specifics**: See `docs/hackathon/` for mock configurations and submission plans.
- **Legal & Security constraints**: See `docs/legal/` (especially around local vault encryption and patient data).