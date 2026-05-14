import 'dart:convert';

import 'package:clindiary/features/prevention_center/domain/prevention_center.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_center_engine.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';

class PreventionCenterRepository {
  const PreventionCenterRepository({PreventionCenterEngine? engine})
    : _engine = engine ?? const PreventionCenterEngine();

  final PreventionCenterEngine _engine;

  Future<PreventionCenterData> fetchCenter({
    required ProfileBundle bundle,
    String? regionCode,
  }) async {
    return _engine.build(bundle, regionCode: regionCode ?? 'IT');
  }
}
