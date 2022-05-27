import 'dart:async';

import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/data/jid.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/presence_stanza.dart';
import 'package:xmpp_stone/src/presence/presence_api.dart';

class PresenceManager implements PresenceApi {
  final Connection _connection;

  late StreamSubscription<XmppConnectionState> _xmppConnectionStateSubscription;
  late StreamSubscription<PresenceStanza?> _presenceStanzaSubscription;

  List<PresenceStanza> requests = <PresenceStanza>[];

  final StreamController<PresenceData> _presenceStreamController = StreamController<PresenceData>.broadcast();

  final StreamController<SubscriptionEvent> _subscribeStreamController =
      StreamController<SubscriptionEvent>.broadcast();
  final StreamController<PresenceErrorEvent> _errorStreamController = StreamController<PresenceErrorEvent>.broadcast();

  PresenceData _selfPresence = PresenceData(PresenceShowElement.chat, '', null);

  PresenceData get selfPresence {
    _selfPresence.jid = _connection.fullJid;
    return _selfPresence;
  }

  set selfPresence(PresenceData value) {
    _selfPresence = value;
  }

  Stream<PresenceData> get presenceStream {
    return _presenceStreamController.stream;
  }

  Stream<SubscriptionEvent> get subscriptionStream {
    return _subscribeStreamController.stream;
  }

  Stream<PresenceErrorEvent> get errorStream {
    return _errorStreamController.stream;
  }

  static Map<Connection, PresenceManager> instances = {};

  static PresenceManager getInstance(Connection connection) {
    var manager = instances[connection];
    if (manager == null) {
      manager = PresenceManager(connection);
      instances[connection] = manager;
    }
    return manager;
  }

  static void removeInstance(Connection connection) {
    instances[connection]?._presenceStanzaSubscription.cancel();
    instances[connection]?._xmppConnectionStateSubscription.cancel();
    instances.remove(connection);
  }

  PresenceManager(this._connection) {
    _presenceStanzaSubscription = _connection.inStanzasStream
        .where((abstractStanza) => abstractStanza is PresenceStanza)
        .map((stanza) => stanza as PresenceStanza?)
        .listen(_processPresenceStanza);
    _xmppConnectionStateSubscription =
        _connection.connectionStateStream.listen(_connectionStateHandler);
  }

  @override
  void acceptSubscription(Jid? to) {
    var presenceStanza = PresenceStanza.withType(PresenceType.subscribed);
    presenceStanza.id = _getPresenceId();
    presenceStanza.toJid = to;
    requests.add(presenceStanza);
    _connection.writeStanza(presenceStanza);
  }

  @override
  void declineSubscription(Jid to) {
    var presenceStanza = PresenceStanza.withType(PresenceType.unsubscribed);
    presenceStanza.id = _getPresenceId();
    presenceStanza.toJid = to;
    requests.add(presenceStanza);
    _connection.writeStanza(presenceStanza);
  }

  @override
  void sendDirectPresence(PresenceData presence, Jid to) {
    var presenceStanza = PresenceStanza();
    presenceStanza.toJid = to;
    presenceStanza.show = presence.showElement;
    presenceStanza.status = presence.status;
    _connection.writeStanza(presenceStanza);
  }

  @override
  void askDirectPresence(Jid to) {
    var presenceStanza = PresenceStanza.withType(PresenceType.probe);
    presenceStanza.toJid = to;
    presenceStanza.fromJid = _connection.fullJid;
    _connection.writeStanza(presenceStanza);
  }

  @override
  void sendPresence(PresenceData presence) {
    var presenceStanza = PresenceStanza();
    presenceStanza.show = presence.showElement;
    presenceStanza.status = presence.status;
    _connection.writeStanza(presenceStanza);
  }

  @override
  void subscribe(Jid to) {
    var presenceStanza = PresenceStanza.withType(PresenceType.subscribe);
    presenceStanza.id = _getPresenceId();
    presenceStanza.toJid = to;
    requests.add(presenceStanza);
    _connection.writeStanza(presenceStanza);
  }

  @override
  void unsubscribe(Jid to) {
    var presenceStanza = PresenceStanza.withType(PresenceType.unsubscribe);
    presenceStanza.id = _getPresenceId();
    presenceStanza.toJid = to;
    requests.add(presenceStanza);
    _connection.writeStanza(presenceStanza);
  }

  void _processPresenceStanza(PresenceStanza? presenceStanza) {
    if (presenceStanza!.type == null) {
      //presence event
      _presenceStreamController.add(PresenceData(presenceStanza.show, presenceStanza.status, presenceStanza.fromJid));
    } else {
      switch (presenceStanza.type!) {
        case PresenceType.subscribe:
          var subscriptionEvent = SubscriptionEvent();
          subscriptionEvent.type = SubscriptionEventType.request;
          subscriptionEvent.jid = presenceStanza.fromJid;
          _subscribeStreamController.add(subscriptionEvent);
          break;
        case PresenceType.error:
          _handleErrorEvent(presenceStanza);
          break;
        case PresenceType.unsubscribe:
          break;
        case PresenceType.probe:
          break;
        case PresenceType.subscribed:
          var subscriptionEvent = SubscriptionEvent();
          subscriptionEvent.type = SubscriptionEventType.accepted;
          subscriptionEvent.jid = presenceStanza.fromJid;
          _subscribeStreamController.add(subscriptionEvent);
          break;
        case PresenceType.unsubscribed:
          var subscriptionEvent = SubscriptionEvent();
          subscriptionEvent.type = SubscriptionEventType.declined;
          subscriptionEvent.jid = presenceStanza.fromJid;
          _subscribeStreamController.add(subscriptionEvent);
          break;
        case PresenceType.unavailable:
          //presence event
          _presenceStreamController.add(PresenceData(PresenceShowElement.xa, 'Unavailable', presenceStanza.fromJid));
          break;
      }
    }
  }

  String _getPresenceId() {
    return 'presence${AbstractStanza.getRandomId()}';
  }

  void _connectionStateHandler(XmppConnectionState state) {
    if (state == XmppConnectionState.ready) {
      //_getRosters();
      _sendInitialPresence();
    }
  }

  void _sendInitialPresence() {
    var initialPresence = PresenceStanza();
    _connection.writeStanza(initialPresence);
  }

  void _handleErrorEvent(PresenceStanza presenceStanza) {
    //TODO Add more handling
    var errorEvent = PresenceErrorEvent();
    errorEvent.presenceStanza = presenceStanza;
    var errorTypeString = presenceStanza.getChild('error')?.getAttribute('type')?.value;
    if (errorTypeString != null && errorTypeString == 'modify') {
      errorEvent.type = PresenceErrorType.modify;
    }
    _errorStreamController.add(errorEvent);
  }
}
