import 'dart:async';
import 'package:universal_io/io.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xmpp_stone/src/connection/xmpp_websocket_api.dart';


export 'xmpp_websocket_api.dart';

XmppWebSocket createSocket() {
  return XmppWebSocketHtml();
}

bool isTlsRequired() {
  // return the `false`, cause for the 'html' socket initially creates as secured
  return false;
}

class XmppWebSocketHtml extends XmppWebSocket {
  WebSocketChannel? _socket;
  late String Function(String event) _map;

  XmppWebSocketHtml();

  @override
  Future<XmppWebSocket> connect<S>(String host, int port,
      {String Function(String event)? map}) {
    print('[XmppWebSocketHtml][connect] host: $host, port: $port');
    _socket = WebSocketChannel.connect(
      Uri(
        scheme: 'wss',
        host: host,
        port: port,
      ),
      protocols: ['xmpp'],
    );

    if (map != null) {
      _map = map;
    } else {
      _map = (element) => element;
    }

    return Future.value(this);
  }

  @override
  void close() {
    _socket?.sink.close();
  }

  @override
  void write(Object? message) {
    _socket?.sink.add(message);
  }

  @override
  StreamSubscription<String> listen(void Function(String event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _socket!.stream.map((event) => event.toString()).map(_map).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }

  @override
  Future<SecureSocket?> secure(
      {host,
      SecurityContext? context,
      bool Function(X509Certificate certificate)? onBadCertificate,
      List<String>? supportedProtocols}) {
    // return the `null`, cause for the 'html' socket initially creates as secured
    return Future.value(null);
  }
}
