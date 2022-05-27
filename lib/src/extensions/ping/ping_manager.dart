import 'dart:async';

import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/iq_stanza.dart';
import 'package:xmpp_stone/src/connection.dart';

class PingManager {

  final Connection _connection;

  static final Map<Connection, PingManager> _instances = {};

  late StreamSubscription<XmppConnectionState> _xmppConnectionStateSubscription;
  late StreamSubscription<AbstractStanza?> _abstractStanzaSubscription;

  PingManager(this._connection) {
    _xmppConnectionStateSubscription =
        _connection.connectionStateStream.listen(_connectionStateProcessor);
    _abstractStanzaSubscription =
        _connection.inStanzasStream.listen(_processStanza);
  }

  static PingManager getInstance(Connection connection) {
    var manager = _instances[connection];
    if (manager == null) {
      manager = PingManager(connection);
      _instances[connection] = manager;
    }
    return manager;
  }

  static void removeInstance(Connection connection) {
    _instances[connection]?._abstractStanzaSubscription.cancel();
    _instances[connection]?._xmppConnectionStateSubscription.cancel();
    _instances.remove(connection);
  }

  void _connectionStateProcessor(XmppConnectionState event) {
    // connection state processor.
  }

  void _processStanza(AbstractStanza? stanza) {
    if (stanza is IqStanza) {
      if (stanza.type == IqStanzaType.get) {
        var ping = stanza.getChild('ping');
        if (ping != null) {
          var iqStanza = IqStanza(stanza.id, IqStanzaType.result);
          iqStanza.fromJid = _connection.fullJid;
          iqStanza.toJid = stanza.fromJid;
          _connection.writeStanza(iqStanza);
        }
      } else if (stanza.type == IqStanzaType.error) {
        //todo handle error cases
      }
    }
  }
}
