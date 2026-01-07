// Mobile implementation for games_services (iOS/Android)
// This file imports and re-exports the real games_services package classes
import 'package:games_services/games_services.dart';

// Re-export the classes so they're available when this file is conditionally imported
export 'package:games_services/games_services.dart' show GamesServices, Achievement, Score;
