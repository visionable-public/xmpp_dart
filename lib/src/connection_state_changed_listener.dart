import 'package:xmpp_stone/src/connection.dart';

abstract class ConnectionStateChangedListener {
  void onConnectionStateChanged(XmppConnectionState state);
}
