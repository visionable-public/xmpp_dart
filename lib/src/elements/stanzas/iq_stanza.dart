import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';

import 'abstract_stanza.dart';

class IqStanza extends AbstractStanza {
  IqStanzaType type = IqStanzaType.set;

  IqStanza(String? id, this.type) {
    name = 'iq';
    this.id = id;
    addAttribute(
        XmppAttribute('type', type.toString().split('.').last.toLowerCase()));
  }
}

enum IqStanzaType { error, set, result, get, invalid, timeout }

class IqStanzaResult {
  IqStanzaType? type;
  String? description;
  String? iqStanzaId;
}
