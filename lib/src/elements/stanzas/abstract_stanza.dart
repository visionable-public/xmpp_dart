import 'dart:math';

import 'package:xmpp_stone/src/data/jid.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';

abstract class AbstractStanza extends XmppElement {
  String? _id;
  Jid? _fromJid;
  Jid? _toJid;

  Jid? get fromJid => _fromJid;

  set fromJid(Jid? value) {
    _fromJid = value;
    addAttribute(XmppAttribute('from', _fromJid!.fullJid));
  }

  Jid? get toJid => _toJid;

  set toJid(Jid? value) {
    _toJid = value;
    addAttribute(XmppAttribute('to', _toJid!.userAtDomain));
  }

  String? get id => _id;

  set id(String? value) {
    _id = value;
    addAttribute(XmppAttribute('id', _id));
  }

  static String getRandomId() {
    const asciiStart = 65;
    const asciiEnd = 90;
    var codeUnits = List.generate(9, (index) {
      return Random.secure().nextInt(asciiEnd - asciiStart) + asciiStart;
    });
    return String.fromCharCodes(codeUnits);
  }
}
