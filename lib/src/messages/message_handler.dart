import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/data/jid.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/message_stanza.dart';
import 'package:xmpp_stone/src/messages/message_api.dart';

class MessageHandler implements MessageApi {
  static Map<Connection, MessageHandler> instances = {};

  Stream<MessageStanza?> get messagesStream {
    return _connection.inStanzasStream
        .where((abstractStanza) => abstractStanza is MessageStanza)
        .map((stanza) => stanza as MessageStanza?);
  }

  static MessageHandler getInstance(Connection connection) {
    var manager = instances[connection];
    if (manager == null) {
      manager = MessageHandler(connection);
      instances[connection] = manager;
    }

    return manager;
  }

  static void removeInstance(Connection connection) {
    instances.remove(connection);
  }

  final Connection _connection;

  MessageHandler(this._connection);

  @override
  void sendMessage(Jid to, String text) {
    _sendMessageStanza(to, text);
  }

  void _sendMessageStanza(Jid jid, String text) {
    var stanza =
        MessageStanza(AbstractStanza.getRandomId(), MessageStanzaType.chat);
    stanza.toJid = jid;
    stanza.fromJid = _connection.fullJid;
    stanza.body = text;
    _connection.writeStanza(stanza);
  }
}
