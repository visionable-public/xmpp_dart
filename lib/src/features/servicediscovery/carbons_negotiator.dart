import 'dart:async';

import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/iq_stanza.dart';
import '../negotiator.dart';
import 'feature.dart';

class CarbonsNegotiator extends Negotiator {

  static const tag = 'CarbonsNegotiator';

  static final Map<Connection, CarbonsNegotiator> _instances = {};


  static CarbonsNegotiator getInstance(Connection connection) {
    var instance = _instances[connection];
    if (instance == null) {
      instance = CarbonsNegotiator(connection);
      _instances[connection] = instance;
    }
    return instance;
  }

  static void removeInstance(Connection connection) {
    _instances[connection]?._subscription?.cancel();
    _instances.remove(connection);
  }

  final Connection _connection;

  bool enabled = false;

  StreamSubscription<AbstractStanza?>? _subscription;
  late IqStanza _myUnrespondedIqStanza;

  CarbonsNegotiator(this._connection) {
    expectedName = 'urn:xmpp:carbons';
  }

  @override
  List<Nonza> match(List<Nonza> request) {
    return (request.where((element) =>
         element is Feature &&
        ((element).xmppVar == 'urn:xmpp:carbons:2' ||
            (element).xmppVar == 'urn:xmpp:carbons:rules:0'))).toList();
  }

  @override
  void negotiate(List<Nonza> nonza) {
    if (match(nonza).isNotEmpty) {
      state = NegotiatorState.negotiating;
      sendRequest();
      _subscription= _connection.inStanzasStream.listen(checkStanzas);
    }
  }

  void sendRequest() {
    var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.set);
    iqStanza.addAttribute(XmppAttribute('xmlns', 'jabber:client'));
    var element = XmppElement();
    element.name = 'enable';
    element.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:carbons:2'));
    iqStanza.addChild(element);
    _myUnrespondedIqStanza = iqStanza;
    _connection.writeStanza(iqStanza);
  }

  void checkStanzas(AbstractStanza? stanza) {
    if (stanza is IqStanza && stanza.id == _myUnrespondedIqStanza.id) {
      enabled = stanza.type == IqStanzaType.result;
      state = NegotiatorState.done;
      _subscription?.cancel();
    }
  }
}
