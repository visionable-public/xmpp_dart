import 'package:xml/xml.dart' as xml;
import 'package:xmpp_stone/src/data/jid.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/forms/field_element.dart';
import 'package:xmpp_stone/src/elements/forms/x_element.dart';
import 'package:xmpp_stone/src/elements/stanzas/abstract_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/message_stanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/presence_stanza.dart';
import 'package:xmpp_stone/src/features/servicediscovery/feature.dart';
import 'package:xmpp_stone/src/features/servicediscovery/identity.dart';
import 'package:xmpp_stone/src/parser/iq_parser.dart';

import '../elements/stanzas/message_stanza.dart';
import '../logger/log.dart';

class StanzaParser {
  static const tag = 'StanzaParser';

  //TODO: Improve this!
  static AbstractStanza? parseStanza(xml.XmlElement element) {
    AbstractStanza? stanza;
    var id = element.getAttribute('id');
    if (id == null) {
      Log.d(tag, 'No id found for stanza');
    }

    if (element.name.local == 'iq') {
      stanza = IqParser.parseIqStanza(id, element);
    } else if (element.name.local == 'message') {
      stanza = _parseMessageStanza(id, element);
    } else if (element.name.local == 'presence') {
      stanza = _parsePresenceStanza(id, element);
    }
    var fromString = element.getAttribute('from');
    if (fromString != null) {
      var from = Jid.fromFullJid(fromString);
      stanza!.fromJid = from;
    }
    var toString = element.getAttribute('to');
    if (toString != null) {
      var to = Jid.fromFullJid(toString);
      stanza!.toJid = to;
    }
    for (var xmlAttribute in element.attributes) {
      stanza!.addAttribute(
          XmppAttribute(xmlAttribute.name.local, xmlAttribute.value));
    }
    for (var child in element.children) {
      if (child is xml.XmlElement) stanza!.addChild(parseElement(child));
    }
    return stanza;
  }

  static MessageStanza _parseMessageStanza(String? id, xml.XmlElement element) {
    var typeString = element.getAttribute('type');
    MessageStanzaType? type;
    if (typeString == null) {
      Log.w(tag, 'No type found for message stanza');
    } else {
      switch (typeString) {
        case 'chat':
          type = MessageStanzaType.chat;
          break;
        case 'error':
          type = MessageStanzaType.error;
          break;
        case 'groupchat':
          type = MessageStanzaType.groupChat;
          break;
        case 'headline':
          type = MessageStanzaType.headline;
          break;
        case 'normal':
          type = MessageStanzaType.normal;
          break;
      }
    }
    var stanza = MessageStanza(id, type);

    return stanza;
  }

  static PresenceStanza _parsePresenceStanza(
      String? id, xml.XmlElement element) {
    var presenceStanza = PresenceStanza();
    presenceStanza.id = id;
    return presenceStanza;
  }

  static XmppElement parseElement(xml.XmlElement xmlElement) {
    XmppElement xmppElement;
    var parentName = (xmlElement.parent as xml.XmlElement?)?.name.local ?? '';
    var name = xmlElement.name.local;
    if (parentName == 'query' && name == 'identity') {
      xmppElement = Identity();
    } else if (parentName == 'query' && name == 'feature') {
      xmppElement = Feature();
    } else if (name == 'x') {
      xmppElement = XElement();
    } else if (name == 'field') {
      xmppElement = FieldElement();
    } else {
      xmppElement = XmppElement();
    }
    xmppElement.name = xmlElement.name.local;
    for (var xmlAttribute in xmlElement.attributes) {
      xmppElement.addAttribute(
          XmppAttribute(xmlAttribute.name.local, xmlAttribute.value));
    }
    for (var xmlChild in xmlElement.children) {
      if (xmlChild is xml.XmlElement) {
        xmppElement.addChild(parseElement(xmlChild));
      } else if (xmlChild is xml.XmlText) {
        xmppElement.textValue = xmlChild.text;
      }
    }
    return xmppElement;
  }
}
