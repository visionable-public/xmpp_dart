import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/data/jid.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/iq_stanza.dart';
import 'package:xmpp_stone/src/features/negotiator.dart';
import '../elements/nonzas/nonza.dart';

class BindingResourceConnectionNegotiator extends Negotiator {
  final Connection _connection;
  late StreamSubscription<AbstractStanza?> subscription;
  static const String kBindName = 'bind';
  static const String kBindAttribute = 'urn:ietf:params:xml:ns:xmpp-bind';

  BindingResourceConnectionNegotiator(this._connection) {
    priorityLevel = 100;
    expectedName = 'BindingResourceConnectionNegotiator';
  }
  @override
  List<Nonza> match(List<Nonza> request) {
    var nonza = request.firstWhereOrNull((request) => request.name == kBindName);
    return nonza != null ? [nonza] : [];
  }

  @override
  void negotiate(List<Nonza> nonza) {
    if (match(nonza).isNotEmpty) {
      state = NegotiatorState.negotiating;
      subscription = _connection.inStanzasStream.listen(parseStanza);
      sendBindRequestStanza(_connection.account.resource);
    }
  }

  void parseStanza(AbstractStanza? stanza) {
    if (stanza is IqStanza) {
      var element = stanza.getChild(kBindName);
      var jidValue = element?.getChild('jid')?.textValue;
      if (jidValue != null) {
        var jid = Jid.fromFullJid(jidValue);
        _connection.fullJidRetrieved(jid);
        state = NegotiatorState.done;
        subscription.cancel();
      }
    }
  }

  void sendBindRequestStanza(String? resource) {
    var stanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.set);
    var bindElement = XmppElement();
    bindElement.name = kBindName;
    var resourceElement = XmppElement();
    resourceElement.name = 'resource';
    resourceElement.textValue = resource;
    bindElement.addChild(resourceElement);
    var attribute = XmppAttribute('xmlns', kBindAttribute);
    bindElement.addAttribute(attribute);
    stanza.addChild(bindElement);
    _connection.writeStanza(stanza);
  }
}
