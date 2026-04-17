# ClinDiary - Public Submission Playbook (Kaggle)

This playbook is for creating a clean public repository that is compliant with hackathon rules and safe to share.

## 1) Mandatory Public Assets

Prepare these before final submission:

1. Public code repository URL.
2. Public video demo URL.
3. Public writeup (up to platform limit).
4. Live demo link or downloadable demo artifact (APK or equivalent).
5. Media gallery items (screenshots and optional short clips).

## 2) Non-Negotiable Security Rules

1. Never commit real secrets.
2. Keep only `.env.example` files in git.
3. Do not commit signing keys, keystores, OAuth client secrets, or service credentials.
4. If the repository is public, cloning cannot be prevented.
5. Protect important assets by architecture, not by trying to block cloning.

Architecture protection means:

1. Keep production infrastructure private.
2. Keep real backend endpoints and credentials outside the public repo.
3. Keep private data and analytics exports outside git.
4. Use mocked backend adapters for demo-only server flows.

## 3) Clean Public Repo Flow

1. Create a new public repository dedicated to submission.
2. Copy only required source and documentation.
3. Add a concise root README that explains what is implemented and what is mocked.
4. Run a final secret scan before first public push.
5. Push and verify the repo is publicly accessible without authentication.

Recommended local validation commands (PowerShell):

```powershell
# From repository root

git ls-files | Select-String -Pattern "(\.env$|\.env\.|key\.properties|\.jks$|\.keystore$|google-services\.json|GoogleService-Info\.plist)"

git ls-files | Select-String -Pattern "(secret|token|password|api[_-]?key|private[_-]?key)"
```

Interpretation:

1. `.env.example` matches are expected.
2. Test fixtures that contain dummy tokens can be expected.
3. Any real credential-looking value must be removed and rotated before publish.

## 4) Suggested Include/Exclude

Include:

1. `apps/mobile` source code needed to run demo app.
2. `apps/backend` only if needed for mocked or local demo behavior.
3. `docs/` files describing architecture, privacy, and evaluation.
4. Build/run scripts that improve reproducibility.

Exclude:

1. Any real `.env` file.
2. Any keystore/signing material.
3. Local caches and generated build artifacts.
4. Private datasets or user exports.
5. Internal notes that contain strategic or sensitive business details not required by judges.

## 5) Final Pre-Publish Checklist

1. Confirm no real credentials are in tracked files.
2. Confirm README states demo scope and mocked components.
3. Confirm video, writeup, and repo tell a consistent technical story.
4. Confirm judges can run or inspect the project without private dependencies.
5. Confirm all required URLs are public.

## 6) Public Repo Positioning Statement

Use this short statement in README and writeup:

"This repository is the public submission package for the hackathon demo. For security and reproducibility, production infrastructure and private credentials are not included. Some backend services are intentionally mocked in this submission; see documentation for the exact real-vs-mocked breakdown."
