import 'package:flutter/foundation.dart';

/// Run state shared by both shells: hearts, solved encounters, checkpoint.
/// Failure is kind: defeat restores hearts and returns the player to the
/// last checkpoint, keeping everything already solved.
class GameSession extends ChangeNotifier {
  GameSession({this.maxHearts = 5, this.timerScale = 1.0});

  final int maxHearts;

  /// Difficulty knob from the menu (0.75 = harder/faster … 1.5 = gentler).
  final double timerScale;

  int _hearts = 5;
  int get hearts => _hearts;
  bool get defeated => _hearts <= 0;

  final Set<String> solvedIds = {};
  String? checkpointId;

  int get solvedCount => solvedIds.length;

  void loseHeart() {
    if (_hearts <= 0) return;
    _hearts--;
    notifyListeners();
  }

  void solve(String encounterId) {
    solvedIds.add(encounterId);
    notifyListeners();
  }

  void reachCheckpoint(String id) {
    checkpointId = id;
    notifyListeners();
  }

  /// Retry after defeat: hearts restored, progress kept.
  void retryFromCheckpoint() {
    _hearts = maxHearts;
    notifyListeners();
  }

  void resetAll() {
    _hearts = maxHearts;
    solvedIds.clear();
    checkpointId = null;
    notifyListeners();
  }
}
