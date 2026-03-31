import 'package:flutter/foundation.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int value) {
    if (_currentIndex == value) {
      return;
    }
    _currentIndex = value;
    notifyListeners();
  }
}
