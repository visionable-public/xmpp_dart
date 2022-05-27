import 'package:xmpp_stone/src/elements/stanzas/message_stanza.dart';

abstract class MessagesListener {
  void onNewMessage(MessageStanza? message);
}
