# AI Bootstrap Notes

## Model Artifact

- Expected model file: `gemma-4-E2B-it.litertlm`
- Runtime: `flutter_gemma 0.15.0` over LiteRT-LM
- Provider label: `Gemma local`
- Download URL is pinned to Hugging Face revision `b4f4f4df93418ddb4aa7da8bf33b584602a5b9f8` so judges do not receive a silently changed artifact.
- Expected size: `2588147712` bytes.
- Minimum validation size: 100 MB, followed by exact-size validation for the pinned artifact.
- Runtime verification opens Gemma 4 E2B with the same 4096-token context used for generation; speculative decoding is disabled by default for release stability.

## App-Owned Model Path

- ClinDiary now uses the `flutter_gemma` app documents location as the app-owned model path.
- On Android this resolves through `path_provider`; the runtime-corrected path is typically `/data/data/it.clindiary.clindiary/app_flutter/gemma-4-E2B-it.litertlm`.
- The app no longer scans arbitrary local model locations.
- The app no longer trusts stale `modelInstalled`-style preferences or `FlutterGemma.isModelInstalled()` as readiness proof.
- Manual import copies the selected `.litertlm` into the app-owned path before runtime activation.

## State Machine

- `notStarted`: bootstrap has not emitted a concrete step yet.
- `checkingAppOwnedModelState`: the app is validating the exact expected artifact path.
- `installingOrDownloading`: the model is being downloaded or installed into app-owned storage.
- `verifying`: the app is activating the model and opening the LiteRT-LM runtime.
- `ready`: artifact validation and runtime open/close verification succeeded.
- `failed`: setup failed; UI shows the error, retry button, and continue-without-AI option.

## Failure Handling

- Missing file: stale plugin metadata is cleared, then the app downloads/reinstalls.
- Too-small file: exact app-owned file and its partial import/download siblings are removed, then setup can retry.
- Wrong-size file: exact app-owned file and its partial import/download siblings are removed, then setup can retry from the pinned artifact URL.
- No internet: bootstrap enters `failed` with a retryable error; the rest of the app remains usable.
- Runtime open failure: setup retries CPU fallback if GPU fails; both paths use 4096 tokens and speculative decoding off. If CPU also fails, AI is marked unavailable.
- Unsupported platform: status reports local Gemma unavailable instead of crashing.
- Inference timeout or empty response: the runtime is reset and the UI surfaces an explicit error.

## Reset And Retry

- Open `Manage model` from the AI proof/status card.
- Use `Prepare/download Gemma` or `Verify/reinstall Gemma` to rerun the app-owned bootstrap.
- Use `Import .litertlm model` to copy a known-good file into the app-owned path.
- Use `Remove model` to delete the exact app-owned model artifact and clear plugin metadata.
- Relaunching the app reruns the bootstrap provider and revalidates the app-owned path.

## Inference Verification

- Open `Manage model`.
- Confirm provider/model/runtime and app-owned path are visible.
- Tap `Run test prompt`.
- Expected prompt: “Summarize this demo diary entry in 3 cautious bullet points. Do not diagnose.”
- Expected result: non-empty Gemma text with cautious, non-diagnostic wording.
- Current pass did not complete real-device inference because APK install was blocked by `INSTALL_FAILED_USER_RESTRICTED` on the connected Android device.
