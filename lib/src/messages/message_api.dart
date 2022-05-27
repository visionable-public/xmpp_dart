import 'package:xmpp_stone/src/data/jid.dart';

abstract class MessageApi {
  void sendMessage(Jid to, String text);
}
