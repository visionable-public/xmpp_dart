import 'dart:async';

import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/chat/message.dart';
import 'package:xmpp_stone/src/data/jid.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/message_stanza.dart';
import 'message.dart';

class ChatImpl implements Chat {

  static String tag = 'Chat';

  final Connection _connection;
  final Jid _jid;

  @override
  Jid get jid => _jid;
  ChatState? _myState;
  @override
  ChatState? get myState => _myState;

  ChatState? _remoteState;
  @override
  ChatState? get remoteState => _remoteState;

  @override
  List<Message>? messages = [];

  final StreamController<Message> _newMessageController =
      StreamController.broadcast();
  final StreamController<ChatState?> _remoteStateController =
      StreamController.broadcast();

  @override
  Stream<Message> get newMessageStream => _newMessageController.stream;
  @override
  Stream<ChatState?> get remoteStateStream => _remoteStateController.stream;

  ChatImpl(this._jid, this._connection);

  void parseMessage(Message message) {
    if (message.type == MessageStanzaType.chat) {
      if (message.text != null && message.text!.isNotEmpty) {
        messages!.add(message);
        _newMessageController.add(message);
      }

      if (message.chatState != null && !(message.isDelayed ?? false)) {
        _remoteState = message.chatState;
        _remoteStateController.add(message.chatState);
      }
    }
  }

  @override
  void sendMessage(String text) {
    var stanza =
        MessageStanza(AbstractStanza.getRandomId(), MessageStanzaType.chat);
    stanza.toJid = _jid;
    stanza.fromJid = _connection.fullJid;
    stanza.body = text;
    var message = Message.fromStanza(stanza);
    messages!.add(message);
    _newMessageController.add(message);
    _connection.writeStanza(stanza);
  }

  @override
  set myState(ChatState? state) {
    var stanza =
        MessageStanza(AbstractStanza.getRandomId(), MessageStanzaType.chat);
    stanza.toJid = _jid;
    stanza.fromJid = _connection.fullJid;
    var stateElement = XmppElement();
    stateElement.name = state.toString().split('.').last.toLowerCase();
    stateElement.addAttribute(
        XmppAttribute('xmlns', 'http://jabber.org/protocol/chatstates'));
    stanza.addChild(stateElement);
    _connection.writeStanza(stanza);
    _myState = state;
  }
}

abstract class Chat {
  Jid get jid;
  ChatState? get myState;
  ChatState? get remoteState;
  Stream<Message> get newMessageStream;
  Stream<ChatState?> get remoteStateStream;
  List<Message>? messages;
  void sendMessage(String text);
  set myState(ChatState? state);
}

enum ChatState { inactive, active, gone, composing, paused }
