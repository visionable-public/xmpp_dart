import 'dart:async';

import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/forms/field_element.dart';
import 'package:xmpp_stone/src/elements/forms/query_element.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/iq_stanza.dart';
import '../../connection.dart';
import '../../elements/nonzas/nonza.dart';
import '../negotiator.dart';
import 'feature.dart';

class MAMNegotiator extends Negotiator {
  static const tag = 'MAMNegotiator';

  static final Map<Connection, MAMNegotiator> _instances = {};

  static MAMNegotiator getInstance(Connection connection) {
    var instance = _instances[connection];
    if (instance == null) {
      instance = MAMNegotiator(connection);
      _instances[connection] = instance;
    }
    return instance;
  }

  static void removeInstance(Connection connection) {
    _instances[connection]?._subscription?.cancel();
    _instances.remove(connection);
  }

  late IqStanza _myUnrespondedIqStanza;

  StreamSubscription<AbstractStanza?>? _subscription;

  final Connection _connection;

  final List<MamQueryParameters> _supportedParameters = [];

  bool enabled = false;

  bool? hasExtended;

  MAMNegotiator(this._connection) {
    expectedName = 'urn:xmpp:mam';
  }

  bool get isQueryByIdSupported =>
      _supportedParameters.contains(MamQueryParameters.beforeId) &&
      _supportedParameters.contains(MamQueryParameters.afterId);

  bool get isQueryByDateSupported =>
      _supportedParameters.contains(MamQueryParameters.start) &&
      _supportedParameters.contains(MamQueryParameters.end);

  bool get isQueryByJidSupported =>
      _supportedParameters.contains(MamQueryParameters.withF);

  @override
  List<Nonza> match(List<Nonza> request) {
    return request
        .where((element) =>
            element is Feature &&
            ((element).xmppVar == 'urn:xmpp:mam:2' ||
                (element).xmppVar == 'urn:xmpp:mam:2#extended'))
        .toList();
  }

  @override
  void negotiate(List<Nonza> nonza) {
    if (match(nonza).isNotEmpty) {
      enabled = true;
      state = NegotiatorState.negotiating;
      sendRequest();
      _subscription = _connection.inStanzasStream.listen(checkStanzas);
    }
  }

  void sendRequest() {
    var iqStanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.get);
    var query = QueryElement();
    query.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:mam:2'));
    iqStanza.addChild(query);
    _myUnrespondedIqStanza = iqStanza;
    _connection.writeStanza(iqStanza);
  }

  void checkStanzas(AbstractStanza? stanza) {
    if (stanza is IqStanza && stanza.id == _myUnrespondedIqStanza.id) {
      var x = stanza.getChild('query')?.getChild('x');
      if (x != null) {
        for (var element in x.children) {
          if (element is FieldElement) {
            switch(element.varAttr) {
              case 'start':
                _supportedParameters.add(MamQueryParameters.start);
                break;
              case 'end':
                _supportedParameters.add(MamQueryParameters.end);
                break;
              case 'with':
                _supportedParameters.add(MamQueryParameters.withF);
                break;
              case 'before-id':
                _supportedParameters.add(MamQueryParameters.beforeId);
                break;
              case 'after-id':
                _supportedParameters.add(MamQueryParameters.afterId);
                break;
              case 'ids':
                _supportedParameters.add(MamQueryParameters.ids);
                break;
            }
          }
        }
      }
      state = NegotiatorState.done;
      _subscription?.cancel();
    }
  }

  void checkForExtendedSupport(List<Nonza> nonzas) {
    hasExtended = nonzas.any(
        (element) => (element as Feature).xmppVar == 'urn:xmpp:mam:2#extended');
  }
}

enum MamQueryParameters { withF, start, end, beforeId, afterId, ids }
