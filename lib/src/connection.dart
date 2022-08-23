import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:xml/xml.dart' as xml;
import 'package:synchronized/synchronized.dart';
import 'package:xmpp_stone/src/reconnection_manager.dart';

import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/features/connection_negotatior_manager.dart';
import 'package:xmpp_stone/src/features/servicediscovery/carbons_negotiator.dart';
import 'package:xmpp_stone/src/features/servicediscovery/mam_negotiator.dart';
import 'package:xmpp_stone/src/features/servicediscovery/service_discovery_negotiator.dart';
import 'package:xmpp_stone/src/parser/stanza_parser.dart';
import 'package:xmpp_stone/xmpp_stone.dart';

import 'connection/xmpp_websocket_api.dart'
  if (dart.library.io) 'connection/xmpp_websocket_io.dart'
  if (dart.library.html) 'connection/xmpp_websocket_html.dart' as xmpp_socket;


enum XmppConnectionState {
  idle,
  closed,
  socketOpening,
  socketOpened,
  doneParsingFeatures,
  startTlsFailed,
  authenticationNotSupported,
  plainAuthentication,
  authenticating,
  authenticated,
  authenticationFailure,
  resumed,
  sessionInitialized,
  ready,
  closing,
  forcefullyClosed,
  reconnecting,
  wouldLikeToOpen,
  wouldLikeToClose,
}

class Connection {
  var lock = Lock(reentrant: true);

  static String tag = 'Connection';

  static Map<String, Connection> instances = {};

  XmppAccountSettings account;

  StreamManagementModule? streamManagementModule;

  Jid get serverName {
    if (_serverName != null) {
      return Jid.fromFullJid(_serverName!);
    } else {
      return Jid.fromFullJid(fullJid.domain); //todo move to account.domain!
    }
  } //move this somewhere

  String? _serverName;

  static Connection getInstance(XmppAccountSettings account) {
    var connection = instances[account.fullJid.userAtDomain];
    if (connection == null) {
      connection = Connection(account);
      instances[account.fullJid.userAtDomain] = connection;
    }
    return connection;
  }

  static void removeInstance(XmppAccountSettings account) {
    instances.remove(account);
  }

  String? errorMessage;

  bool authenticated = false;

  final StreamController<AbstractStanza?> _inStanzaStreamController =
      StreamController.broadcast();

  final StreamController<AbstractStanza> _outStanzaStreamController =
      StreamController.broadcast();

  final StreamController<Nonza> _inNonzaStreamController =
      StreamController.broadcast();

  final StreamController<Nonza> _outNonzaStreamController =
      StreamController.broadcast();

  final StreamController<XmppConnectionState> _connectionStateStreamController =
      StreamController.broadcast();

  Stream<AbstractStanza?> get inStanzasStream {
    return _inStanzaStreamController.stream;
  }

  Stream<Nonza> get inNonzasStream {
    return _inNonzaStreamController.stream;
  }

  Stream<Nonza> get outNonzasStream {
    return _inNonzaStreamController.stream;
  }

  Stream<AbstractStanza> get outStanzasStream {
    return _outStanzaStreamController.stream;
  }

  Stream<XmppConnectionState> get connectionStateStream {
    return _connectionStateStreamController.stream;
  }

  Jid get fullJid => account.fullJid;

  late ConnectionNegotiatorManager connectionNegotatiorManager;

  void fullJidRetrieved(Jid jid) {
    account.resource = jid.resource;
  }

  xmpp_socket.XmppWebSocket? _socket;

  // for testing purpose
  set socket(xmpp_socket.XmppWebSocket? value) {
    _socket = value;
  }

  XmppConnectionState _state = XmppConnectionState.idle;

  ReconnectionManager? reconnectionManager;

  Connection(this.account) {
    RosterManager.getInstance(this);
    PresenceManager.getInstance(this);
    MessageHandler.getInstance(this);
    PingManager.getInstance(this);
    connectionNegotatiorManager = ConnectionNegotiatorManager(this, account);
    reconnectionManager = ReconnectionManager(this);
  }

  void _openStream() {
    var streamOpeningString = """
<?xml version='1.0'?>
<stream:stream xmlns='jabber:client' version='1.0' xmlns:stream='http://etherx.jabber.org/streams'
to='${fullJid.domain}'
xml:lang='en'
>
""";
    write(streamOpeningString);
  }

  String restOfResponse = '';

  String extractWholeChild(String response) {
    return response;
  }

  String prepareStreamResponse(String response) {
    Log.xmppReceiving(response);
    var response1 = extractWholeChild(restOfResponse + response);
    if (response1.contains('</stream:stream>')) {
      close();
      return '';
    }
    if (response1.contains('stream:stream') &&
        !(response1.contains('</stream:stream>'))) {
      response1 = '$response1</stream:stream>'; // fix for crashing xml library without ending
    }

    //fix for multiple roots issue
    response1 = '<xmpp_stone>$response1</xmpp_stone>';
    return response1;
  }

  void reconnect() {
    if (_state == XmppConnectionState.forcefullyClosed) {
      setState(XmppConnectionState.reconnecting);
      openSocket();
    }
  }

  void connect() {
    if (_state == XmppConnectionState.closing) {
      _state = XmppConnectionState.wouldLikeToOpen;
    }
    if (_state == XmppConnectionState.closed) {
      _state = XmppConnectionState.idle;
    }
    if (_state == XmppConnectionState.idle) {
      openSocket();
    }
  }

  Future<void> openSocket() async {
    connectionNegotatiorManager.init();
    setState(XmppConnectionState.socketOpening);
    try {

      var socket = xmpp_socket.createSocket();

      return await socket.connect(account.host ?? account.domain, account.port, map: prepareStreamResponse).then((socket) {
        // if not closed in meantime
        if (_state != XmppConnectionState.closed) {
          setState(XmppConnectionState.socketOpened);
          _socket = socket;
          socket
              .listen(handleResponse, onDone: handleConnectionDone);
          _openStream();
        } else {
          Log.d(tag, 'Closed in meantime');
          socket.close();
        }
      });
    } catch (error) {
      Log.e(tag, 'Socket Exception$error');
      handleConnectionError(error.toString());
    }
  }

  void close() {
    if (state == XmppConnectionState.socketOpening) {
      throw Exception('Closing is not possible during this state');
    }
    if (state != XmppConnectionState.closed &&
        state != XmppConnectionState.forcefullyClosed &&
        state != XmppConnectionState.closing) {
      if (_socket != null) {
        try {
          setState(XmppConnectionState.closing);
          _socket!.write('</stream:stream>');
        } on Exception {
          Log.d(tag, 'Socket already closed');
        }
      }
      authenticated = false;
    }
  }

  /// Dispose of the connection so stops all activities and cannot be re-used.
  /// For the connection to be garbage collected.
  /// 
  /// If the Connection instance was created with [getInstance],
  /// you must also call [Connection.removeInstance] after calling [dispose].
  /// 
  /// If you intend to re-use the connection later, consider just calling [close] instead.
  void dispose() {
    close();
    RosterManager.removeInstance(this);
    PresenceManager.removeInstance(this);
    MessageHandler.removeInstance(this);
    PingManager.removeInstance(this);
    ServiceDiscoveryNegotiator.removeInstance(this);
    StreamManagementModule.removeInstance(this);
    CarbonsNegotiator.removeInstance(this);
    MAMNegotiator.removeInstance(this);
    reconnectionManager?.close();
    _socket?.close();
  }

  bool startMatcher(xml.XmlElement element) {
    var name = element.name.local;
    return name == 'stream';
  }

  bool stanzaMatcher(xml.XmlElement element) {
    var name = element.name.local;
    return name == 'iq' || name == 'message' || name == 'presence';
  }

  bool nonzaMatcher(xml.XmlElement element) {
    var name = element.name.local;
    return name != 'iq' && name != 'message' && name != 'presence';
  }

  bool featureMatcher(xml.XmlElement element) {
    var name = element.name.local;
    return (name == 'stream:features' || name == 'features');
  }

  String _unparsedXmlResponse = '';

  void handleResponse(String response) {
    String fullResponse;
    if (_unparsedXmlResponse.isNotEmpty) {
      if (response.length > 12) {
        fullResponse = '$_unparsedXmlResponse${response.substring(12)}'; //
      } else {
        fullResponse = _unparsedXmlResponse;
      }
      Log.v(tag, 'full response = $fullResponse');
      _unparsedXmlResponse = '';
    } else {
      fullResponse = response;
    }

    if (fullResponse.isNotEmpty) {
      xml.XmlNode? xmlResponse;
      try {
        xmlResponse = xml.XmlDocument.parse(fullResponse).firstChild;
      } catch (e) {
        _unparsedXmlResponse += fullResponse.substring(
            0, fullResponse.length - 13); //remove  xmpp_stone end tag
        xmlResponse = xml.XmlElement(xml.XmlName('error'));
      }
//      xmlResponse.descendants.whereType<xml.XmlElement>().forEach((element) {
//        Log.d("element: " + element.name.local);
//      });
      //TODO: Improve parser for children only
      xmlResponse!.descendants
          .whereType<xml.XmlElement>()
          .where((element) => startMatcher(element))
          .forEach((element) => processInitialStream(element));

      xmlResponse.children
          .whereType<xml.XmlElement>()
          .where((element) => stanzaMatcher(element))
          .map((xmlElement) => StanzaParser.parseStanza(xmlElement))
          .forEach((stanza) => _inStanzaStreamController.add(stanza));

      xmlResponse.descendants
          .whereType<xml.XmlElement>()
          .where((element) => featureMatcher(element))
          .forEach((feature) =>
              connectionNegotatiorManager.negotiateFeatureList(feature));

      //TODO: Probably will introduce bugs!!!
      xmlResponse.children
          .whereType<xml.XmlElement>()
          .where((element) => nonzaMatcher(element))
          .map((xmlElement) => Nonza.parse(xmlElement))
          .forEach((nonza) => _inNonzaStreamController.add(nonza));
    }
  }

  void processInitialStream(xml.XmlElement initialStream) {
    Log.d(tag, 'processInitialStream');
    var from = initialStream.getAttribute('from');
    if (from != null) {
      _serverName = from;
    }
  }

  bool isOpened() {
    return state != XmppConnectionState.closed &&
        state != XmppConnectionState.forcefullyClosed &&
        state != XmppConnectionState.closing &&
        state != XmppConnectionState.socketOpening;
  }

  void write(message) {
    Log.xmppSending(message);
    if (isOpened()) {
      _socket!.write(message);
    }
  }

  void writeStanza(AbstractStanza stanza) {
    _outStanzaStreamController.add(stanza);
    write(stanza.buildXmlString());
  }

  void writeNonza(Nonza nonza) {
    _outNonzaStreamController.add(nonza);
    write(nonza.buildXmlString());
  }

  void setState(XmppConnectionState state) {
    _state = state;
    _fireConnectionStateChangedEvent(state);
    _processState(state);
    Log.d(tag, 'State: $_state');
  }

  XmppConnectionState get state {
    return _state;
  }

  void _processState(XmppConnectionState state) {
    if (state == XmppConnectionState.authenticated) {
      authenticated = true;
      _openStream();
    } else if (state == XmppConnectionState.closed ||
        state == XmppConnectionState.forcefullyClosed) {
      authenticated = false;
    }
  }

  void processError(xml.XmlDocument xmlResponse) {
    //todo find error stanzas
  }

  void startSecureSocket() {
    Log.d(tag, 'startSecureSocket');

    _socket!.secure(onBadCertificate: _validateBadCertificate).
        then((secureSocket) {
          if(secureSocket == null) return;

      secureSocket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .map(prepareStreamResponse)
          .listen(handleResponse,
              onError: (error) =>
                  {handleSecuredConnectionError(error.toString())},
              onDone: handleSecuredConnectionDone);
      _openStream();
    });
  }

  void fireNewStanzaEvent(AbstractStanza stanza) {
    _inStanzaStreamController.add(stanza);
  }

  void _fireConnectionStateChangedEvent(XmppConnectionState state) {
    _connectionStateStreamController.add(state);
  }

  bool elementHasAttribute(xml.XmlElement element, xml.XmlAttribute attribute) {
    var list = element.attributes.firstWhereOrNull((attr) =>
        attr.name.local == attribute.name.local &&
        attr.value == attribute.value);
    return list != null;
  }

  void sessionReady() {
    setState(XmppConnectionState.sessionInitialized);
    //now we should send presence
  }

  void doneParsingFeatures() {
    if (state == XmppConnectionState.sessionInitialized) {
      setState(XmppConnectionState.ready);
    }
  }

  void startTlsFailed() {
    setState(XmppConnectionState.startTlsFailed);
    close();
  }

  void authenticating() {
    setState(XmppConnectionState.authenticating);
  }

  bool _validateBadCertificate(X509Certificate certificate) {
    return true;
  }

  bool isTlsRequired() {
    return xmpp_socket.isTlsRequired();
  }

  void handleConnectionDone() {
    Log.d(tag, 'Handle connection done');
    handleCloseState();
  }

  void handleSecuredConnectionDone() {
    Log.d(tag, 'Handle secured connection done');
    handleCloseState();
  }

  void handleConnectionError(String error) {
    handleCloseState();
  }

  void handleCloseState() {
    if (state == XmppConnectionState.wouldLikeToOpen) {
      setState(XmppConnectionState.closed);
      connect();
    } else if (state != XmppConnectionState.closing) {
      setState(XmppConnectionState.forcefullyClosed);
    } else {
      setState(XmppConnectionState.closed);
    }
  }

  void handleSecuredConnectionError(String error) {
    Log.d(tag, 'Handle Secured Error  $error');
    handleCloseState();
  }

  bool isAsyncSocketState() {
    return state == XmppConnectionState.socketOpening ||
        state == XmppConnectionState.closing;
  }
}
