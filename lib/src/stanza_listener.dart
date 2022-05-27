import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';

abstract class StanzaProcessor {
  void processStanza(AbstractStanza stanza);
}
