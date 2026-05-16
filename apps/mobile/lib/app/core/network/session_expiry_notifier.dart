import 'package:flutter/foundation.dart';

class SessionExpiryNotifier extends ChangeNotifier {
  void notifySessionExpired() {
    notifyListeners();
  }
}
