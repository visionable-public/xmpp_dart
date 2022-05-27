import 'dart:collection';

import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';

class StreamState {
  String? id;
  bool streamManagementEnabled = false;
  bool streamResumeEnabled = false;
  int lastSentStanza = 0;
  int lastReceivedStanza = 0;
  Queue nonConfirmedSentStanzas = Queue<AbstractStanza>();

  bool tryingToResume = false;
  bool isResumeAvailable() => id != null && streamResumeEnabled;
}