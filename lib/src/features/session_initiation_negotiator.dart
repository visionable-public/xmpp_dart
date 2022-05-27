import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/iq_stanza.dart';
import 'package:xmpp_stone/src/features/negotiator.dart';

import '../elements/nonzas/nonza.dart';

class SessionInitiationNegotiator extends Negotiator {
  final Connection _connection;
  StreamSubscription<AbstractStanza?>? subscription;

  IqStanza? sentRequest;

  SessionInitiationNegotiator(this._connection) {
    expectedName = 'SessionInitiationNegotiator';
  }
  @override
  List<Nonza> match(List<Nonza> request) {
    var nonza = request.firstWhereOrNull((request) => request.name == 'session');
    return nonza != null ? [nonza] : [];
  }

  @override
  void negotiate(List<Nonza> nonza) {
    if (match(nonza).isNotEmpty) {
      state = NegotiatorState.negotiating;
      subscription = _connection.inStanzasStream.listen(parseStanza);
      sendSessionInitiationStanza();
    }
  }

  void parseStanza(AbstractStanza? stanza) {
    if (stanza is IqStanza) {
      var idValue = stanza.getAttribute('id')?.value;
      if (idValue != null &&
          idValue == sentRequest?.getAttribute('id')?.value) {
        _connection.sessionReady();
        state = NegotiatorState.done;
      }
    }
  }

  void sendSessionInitiationStanza() {
    var stanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.set);
    var sessionElement = XmppElement();
    sessionElement.name = 'session';
    var attribute =
        XmppAttribute('xmlns', 'urn:ietf:params:xml:ns:xmpp-session');
    sessionElement.addAttribute(attribute);
    stanza.toJid = _connection.serverName;
    stanza.addChild(sessionElement);
    sentRequest = stanza;
    _connection.writeStanza(stanza);
  }
}
