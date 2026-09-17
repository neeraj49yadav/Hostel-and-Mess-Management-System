import 'package:flutter/material.dart';

/// Global application navigator key for safe top-level routing (e.g. security lock).
class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
}
