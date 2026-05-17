# Writeup Text - Backend Mock Disclosure

Use this content in the public writeup. It is designed to be transparent and evaluator-friendly.

## Short Version (paste-ready)

For this hackathon submission, the client experience and Gemma-powered application flows are implemented in the app, while selected cloud/backend integrations are mocked for demo reliability, privacy safety, and reproducibility. The mock layer is explicit in code and documentation, and was used to avoid exposing production credentials or non-public infrastructure. This allows judges to evaluate product design, AI interaction quality, and end-to-end UX without requiring private services.

## Extended Version (paste-ready)

### Implementation Scope and Mocked Services

This submission is intentionally split into two parts:

1. Real application logic that is fully implemented and reviewable in this repository.
2. Mocked backend services for selected server-dependent capabilities.

The app-side architecture, interaction flows, prompt orchestration, UI states, and validation logic are implemented as production-style code. For specific server integrations, we use deterministic mock responses in order to keep the project publicly shareable and reproducible during judging.

### Why We Mocked Part of the Backend

We used mocks for three practical reasons:

1. Security: no production credentials or private infrastructure are exposed in a public competition repository.
2. Reproducibility: judges can run and inspect the same behavior without requiring access to private cloud services.
3. Reliability: demo behavior remains stable in constrained environments and during asynchronous judging.

### What Judges Can Evaluate Reliably

Judges can directly evaluate:

1. Product UX and clinical diary workflow quality.
2. Gemma-related prompt and response handling in the app experience.
3. Data flow, state management, and safety/consent oriented UI design.
4. Technical clarity of architecture and engineering decisions.

### Transparency Commitment

All mocked components are declared in this writeup and corresponding docs. We explicitly avoid presenting mocked server behavior as production deployment readiness.

## Optional One-Liner for README

"Some backend capabilities are intentionally mocked in this public hackathon build to ensure security, reproducibility, and stable judging."
