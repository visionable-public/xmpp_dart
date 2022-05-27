import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';

class MessageStanza extends AbstractStanza {
  MessageStanzaType? type;

  MessageStanza(id, this.type) {
    name = 'message';
    this.id = id;
    addAttribute(
        XmppAttribute('type', type.toString().split('.').last.toLowerCase()));
  }

  String? get body => children
      .firstWhereOrNull((child) => (child.name == 'body' && child.attributes.isEmpty))
      ?.textValue;

  set body(String? value) {
    var element = XmppElement();
    element.name = 'body';
    element.textValue = value;
    addChild(element);
  }

  String? get subject => children
      .firstWhereOrNull((child) => (child.name == 'subject'))
      ?.textValue;

  set subject(String? value) {
    var element = XmppElement();
    element.name = 'subject';
    element.textValue = value;
    addChild(element);
  }

  String? get thread => children
      .firstWhereOrNull((child) => (child.name == 'thread'))
      ?.textValue;

  set thread(String? value) {
    var element = XmppElement();
    element.name = 'thread';
    element.textValue = value;
    addChild(element);
  }
}

enum MessageStanzaType { chat, error, groupChat, headline, normal, unknown }
