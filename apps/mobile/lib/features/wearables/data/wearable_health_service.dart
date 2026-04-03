import 'package:clindiary/features/wearables/data/wearable_health_service_base.dart';
import 'package:clindiary/features/wearables/data/wearable_health_service_impl_stub.dart'
    if (dart.library.io) 'package:clindiary/features/wearables/data/wearable_health_service_impl_io.dart';

export 'package:clindiary/features/wearables/data/wearable_health_service_base.dart';

WearableHealthService createWearableHealthService() =>
    createWearableHealthServiceImpl();
