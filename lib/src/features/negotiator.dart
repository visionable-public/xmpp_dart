import 'dart:async';

import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';

abstract class Negotiator {
  static int defaultPriorityLevel = 1000;

  String? expectedName;
  String? expectedNameSpace;
  NegotiatorState _state = NegotiatorState.idle;
  int priorityLevel = defaultPriorityLevel;

  NegotiatorState get state => _state;

  StreamController<NegotiatorState> negotiatorStateStreamController =
      StreamController<NegotiatorState>.broadcast();

  Stream<NegotiatorState> get featureStateStream {
    return negotiatorStateStreamController.stream;
  }

  set state(NegotiatorState value) {
    _state = value;
    negotiatorStateStreamController.add(state);
  }

  //goes trough all features and match only needed nonzas
  List<Nonza>? match(List<Nonza> request);

  void negotiate(List<Nonza> nonza);

  void backToIdle() {
    state = NegotiatorState.idle;
  }

  bool isReady() {
    return _state != NegotiatorState.done && state != NegotiatorState.doneCleanOthers;
  }

  @override
  String toString() {
    return '{name: $expectedName, name_space: $expectedNameSpace, priority: $priorityLevel, state: $state}, isReady: ${isReady()}';
  }
}

enum NegotiatorState { idle, negotiating, done, doneCleanOthers }
