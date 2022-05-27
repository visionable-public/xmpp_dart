import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/iq_stanza.dart';
import 'package:xmpp_stone/src/features/negotiator.dart';
import 'package:xmpp_stone/src/features/servicediscovery/feature.dart';
import 'package:xmpp_stone/src/features/servicediscovery/identity.dart';
import 'package:xmpp_stone/src/features/servicediscovery/servicediscovery_support.dart';
import 'feature.dart';

class ServiceDiscoveryNegotiator extends Negotiator {
  static const String kNamespaceDiscoInfo =
      'http://jabber.org/protocol/disco#info';

  static final Map<Connection, ServiceDiscoveryNegotiator> _instances = {};

  static ServiceDiscoveryNegotiator getInstance(Connection connection) {
    var instance = _instances[connection];
    if (instance == null) {
      instance = ServiceDiscoveryNegotiator(connection);
      _instances[connection] = instance;
    }
    return instance;
  }

  static void removeInstance(Connection connection) {
    _instances[connection]?.subscription?.cancel();
    _instances.remove(connection);
  }

  IqStanza? fullRequestStanza;

  StreamSubscription<AbstractStanza?>? subscription;

  final Connection _connection;

  ServiceDiscoveryNegotiator(this._connection) {
    _connection.connectionStateStream.listen((state) {
      expectedName = 'ServiceDiscoveryNegotiator';
    });
  }

  final StreamController<XmppElement> _errorStreamController =
      StreamController<XmppElement>();

  final List<Feature> _supportedFeatures = <Feature>[];

  final List<Identity> _supportedIdentities = <Identity>[];

  Stream<XmppElement> get errorStream {
    return _errorStreamController.stream;
  }

  void _parseStanza(AbstractStanza? stanza) {
    if (stanza is IqStanza) {
      var idValue = stanza.getAttribute('id')?.value;
      if (idValue != null &&
          idValue == fullRequestStanza?.getAttribute('id')?.value) {
        _parseFullInfoResponse(stanza);
      } else if (isDiscoInfoQuery(stanza)) {
        sendDiscoInfoResponse(stanza);
      }
    }
  }

  @override
  List<Nonza> match(List<Nonza> request) {
    return [];
  }

  @override
  void negotiate(List<Nonza> nonza) {
    if (state == NegotiatorState.idle) {
      state = NegotiatorState.negotiating;
      subscription = _connection.inStanzasStream.listen(_parseStanza);
      _sendServiceDiscoveryRequest();
    } else if (state == NegotiatorState.done) {
    }
  }

  void _sendServiceDiscoveryRequest() {
    var request = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.get);
    request.fromJid = _connection.fullJid;
    request.toJid = _connection.serverName;
    var queryElement = XmppElement();
    queryElement.name = 'query';
    queryElement.addAttribute(
        XmppAttribute('xmlns', 'http://jabber.org/protocol/disco#info'));
    request.addChild(queryElement);
    fullRequestStanza = request;
    _connection.writeStanza(request);
  }

  void _parseFullInfoResponse(IqStanza stanza) {
    _supportedFeatures.clear();
    _supportedIdentities.clear();
    if (stanza.type == IqStanzaType.result) {
      var queryStanza = stanza.getChild('query');
      if (queryStanza != null) {
        for (var element in queryStanza.children) {
          if (element is Identity) {
            _supportedIdentities.add(element);
          } else if (element is Feature) {
            _supportedFeatures.add(element);
          }
        }
      }
    } else if (stanza.type == IqStanzaType.error) {
      var errorStanza = stanza.getChild('error');
      if (errorStanza != null) {
        _errorStreamController.add(errorStanza);
      }
    }
    subscription?.cancel();
    _connection.connectionNegotatiorManager.addFeatures(_supportedFeatures);
    state = NegotiatorState.done;
  }

  bool isFeatureSupported(String feature) {
    return _supportedFeatures.firstWhereOrNull(
            (element) => element.xmppVar == feature) !=
        null;
  }

  List<Feature> getSupportedFeatures() {
    return _supportedFeatures;
  }

  bool isDiscoInfoQuery(IqStanza stanza) {
    return stanza.type == IqStanzaType.get &&
        stanza.toJid!.fullJid == _connection.fullJid.fullJid &&
        stanza.children
            .where((element) =>
                element.name == 'query' &&
                element.getAttribute('xmlns')?.value == kNamespaceDiscoInfo)
            .isNotEmpty;
  }

  void sendDiscoInfoResponse(IqStanza request) {
    var iqStanza = IqStanza(request.id, IqStanzaType.result);
    //iqStanza.fromJid = _connection.fullJid; //do not send for now
    iqStanza.toJid = request.fromJid;
    var query = XmppElement();
    query.addAttribute(XmppAttribute('xmlns', kNamespaceDiscoInfo));
    for (var featureName in kServiceDiscoverySupportList) {
      var featureElement = XmppElement();
      featureElement.addAttribute(XmppAttribute('feature', featureName));
      query.addChild(featureElement);
    }
    iqStanza.addChild(query);
    _connection.writeStanza(iqStanza);
  }
}

extension ServiceDiscoveryExtension on Connection {
  List<Feature> getSupportedFeatures() {
    return ServiceDiscoveryNegotiator.getInstance(this).getSupportedFeatures();
  }
}