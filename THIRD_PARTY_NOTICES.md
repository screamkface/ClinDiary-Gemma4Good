# Third-party notices

ClinDiary uses third-party software, frameworks, SDKs, tools, and pretrained models.

Unless otherwise stated, third-party components remain under their respective licenses.
The ClinDiary team does not claim ownership over third-party software, SDKs, tools,
or pretrained models.

## Main third-party components

### Flutter and Dart

The mobile application is built with Flutter and Dart.

- Flutter SDK
- Dart SDK
- Android Flutter embedding
- Flutter package ecosystem dependencies

These components remain under their respective licenses.

### Android platform and build tooling

The Android build uses standard Android tooling and related components.

- Android SDK
- Android Gradle Plugin
- Gradle
- Kotlin Android plugin
- Android device runtime libraries

These components remain under their respective licenses.

### Gemma and local inference

ClinDiary uses Gemma 4 locally through the mobile runtime integration.

Relevant components include:

- Gemma model family
- Google AI Edge
- LiteRT / LiteRT-LM
- flutter_gemma

The Gemma model, LiteRT components, and related runtime tooling remain under
their respective licenses and terms.

The ClinDiary project demonstrates how these components can be used in a
privacy-preserving, local-first health diary workflow.

### App dependencies

The app may use packages such as:

- Riverpod for state management
- Drift / SQLite-related packages for local persistence
- GoRouter for navigation
- intl for formatting and localization support
- Flutter plugins for local device capabilities

For the complete list of dependencies, see the relevant project dependency files,
including:

```text
apps/mobile/pubspec.yaml
apps/mobile/pubspec.lock
```

## Demo data

The demo health data included in ClinDiary is synthetic and created for the
Gemma 4 Good Hackathon demonstration.

It does not contain real patient data, real medical records, or real personal
health information.

## Project license

Unless otherwise noted, the original ClinDiary source code, documentation, and
synthetic demo materials created for this hackathon submission are licensed under
CC-BY 4.0 as described in the repository LICENSE file.

Third-party dependencies and pretrained models are not relicensed by this
repository and remain under their own licenses.
