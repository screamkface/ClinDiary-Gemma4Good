# ClinDiary Project Architecture Overview

## 1) What This Project Is

ClinDiary is a production-oriented clinical diary platform built as a monorepo with:

- a Flutter mobile app
- local persistence and processing on device
- scripts for Android demo execution and hackathon flows
- architecture and legal documentation

The product combines deterministic clinical logic with cautious AI-generated summaries. The current hackathon focus is the on-device/private daily recap path powered by Gemma-family models, while safety-critical logic remains deterministic.

## 2) Product Scope (Functional Overview)

Main capabilities implemented in this repository include:

- local profile setup and onboarding
- daily clinical diary entries (symptoms, metrics, notes)
- unified health timeline and event history
- clinical document archive with local processing and manual review
- AI recap/insight generation with explicit runtime/provider visibility
- deterministic red-flag alerts and alert center workflows
- screening and prevention tracking
- medication schedule and adherence logging
- notifications and inbox preferences
- wearable/smartwatch integration data ingestion
- local PDF report generation and export flow
- local rag for documents and diary context (non-hero for hackathon) with on-device indexing and retrieval

Hackathon MVP focus:

- hero feature is `Private / Local Daily Recap`
- Android on-device generation via LiteRT-LM and `.litertlm` model import/provisioning
- fully local processing and generation path

## 3) Monorepo Structure

Top-level structure:

```text
apps/
  mobile/
docs/
  architecture/
  legal/
  hackathon/
scripts/
build_demo_apk.ps1
build_demo_apk.sh
Makefile
README.md
```

### Key folders

- `apps/mobile/`: Flutter client application, feature-first structure
- `docs/architecture/`: architecture documentation (this file)
- `docs/legal/`: governance, compliance, retention, and security notes
- `scripts/`: operational scripts for app launch, model push, demo checks

## 4) Mobile Architecture (Flutter)

The mobile app uses a feature-first layout.

Core structure:

- `lib/main.dart`: app entrypoint
- `lib/app/`: router, global providers, theme/configuration, dependency wiring
- `lib/features/`: domain features grouped by capability
- `lib/shared/`: shared widgets/utilities

Feature pattern:

- `data/`: repository and local persistence access code
- `domain/`: entities/models and business abstractions
- `presentation/`: screens, view state, and UI interactions

Typical mobile stack:

- Flutter
- Riverpod for state management/DI
- GoRouter for navigation
- Drift for local persistence/cache
- secure local storage for sensitive user settings

Design intent:

- resilient offline-friendly behavior through local cache/queue patterns
- clear separation between rendering, domain logic, and integration layers
- fully local runtime execution for core workflows

## 5) Local Service Layer (On Device)

The architecture is organized around mobile-first local execution. All critical user workflows are designed to run on device.

Core responsibilities:

- local profile and diary management
- document import, storage, extraction, indexing, and retrieval on device
- AI recap orchestration and runtime proof/status in-app
- deterministic clinical rules for red flags and screening eligibility
- report generation and local notification scheduling

Async/background model:

- in-app background jobs for document/OCR and scheduled tasks
- retry/fallback behavior for OCR and long-running processing

Storage and runtime dependencies:

- Drift/SQLite for structured local data
- app sandbox file storage for documents and model assets
- LiteRT-LM runtime on Android for on-device generation

## 6) AI Architecture and Safety Boundaries

AI is used as an assistive narrative layer, not as a source of clinical decisions.

Separation of concerns:

- deterministic engine handles safety-critical logic (alerts/screening/prevention)
- AI generation handles recap narrative with constrained prompt context

Runtime paths:

- Android on-device path (LiteRT-LM + local model)
- local deterministic fallback path (`rule_based`)

Safety and product boundaries:

- no diagnosis generation
- no treatment or dosage prescription
- no delegation of red-flag logic to LLM runtime
- explicit provider/runtime badges and proof card for transparency

## 7) Data Domains

Major data domains in the platform:

- local identity/profile data
- patient profile and clinical baseline
- daily diary observations
- device/wearable aggregates
- uploaded documents + extracted text + metadata
- AI recap records/metadata (local runtime path)
- alerts, screenings, medications, adherence, and notifications
- reporting artifacts (PDF and related metadata)

Cross-cutting concerns:

- auditable events for sensitive operations
- local file protection and controlled export/share actions
- integrity checks (for example, hash/signature checks on uploads)

## 8) End-to-End Flow (High-Level)

1. User captures health data in mobile app.
2. Mobile writes local state/cache to on-device persistence.
3. In-app jobs schedule and execute async processing where needed.
4. Local document pipeline extracts/parses/indexes uploaded files.
5. Deterministic engines compute alerts/screening/prevention states.
6. On-device runtime generates cautious recap according to selected mode.
7. Mobile renders output with runtime proof and safety messaging.

## 9) Environments and Operations

Development model:

- local-only app execution on emulator or physical device
- LAN/USB/Wi-Fi Android workflows through provided scripts

Operational aids found in the repo:

- bootstrapping scripts for demo setup
- utility scripts for model push and on-device smoke checks
- release guide for APK packaging

## 10) Security and Compliance Posture

The repository includes dedicated legal/compliance/security documentation under `docs/legal/` that outlines:

- governance and risk considerations
- GDPR and retention planning
- security runbook and pre-launch controls

Architectural security themes implemented/targeted:

- least-privilege local data access patterns
- secure local storage handling on device
- controlled document export paths
- auditability for sensitive events
- explicit separation between deterministic medical logic and LLM output

## 11) Observability and Quality

Quality and diagnostics strategy includes:

- mobile analysis and test artifacts in the app folder
- runtime diagnostics and traces generated by the app runtime
- smoke scripts for validating on-device model path
- phase-based documentation to track feature evolution and delivery milestones

## 12) Current Constraints and Known Direction

Current practical constraints:

- on-device recap currently centered on Android workflow
- full end-to-end offline prompt construction is a follow-up step
- local RAG is intentionally not the hackathon hero feature

Near-term architecture direction:

- hardening AI provider runtime validation and fallback paths
- production billing integration for entitlement tiers
- hardening local notifications and device-level permission flows
- extended wearable/OCR validation on real-world data

## 13) How To Navigate This Codebase Quickly

Start here for orientation:

1. `README.md` for overall capabilities and run paths
2. `apps/mobile/README.md` for mobile module conventions
3. `docs/architecture/actual-situation.md` for current status and pending items
4. `scripts/` for practical execution flows
5. `docs/legal/` for compliance/security baselines

---

This document is intended as a single-entry architecture map for contributors, reviewers, and hackathon judges who need both product context and technical structure at a glance.