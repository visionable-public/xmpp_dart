import 'package:xml/xml.dart' as xml;
import '../elements/stanzas/iq_stanza.dart';
import '../logger/log.dart';

class IqParser {
  static const tag = 'IqParser';

  static IqStanza parseIqStanza(String? id, xml.XmlElement element) {
    var typeString = element.getAttribute('type');
    return IqStanza(id, _parseIqType(typeString));
  }

  static IqStanzaType _parseIqType(String? typeString) {
    if (typeString == null) {
      Log.w(tag, 'No type found for iq stanza');
      return IqStanzaType.invalid;
    } else {
      switch (typeString) {
        case 'error':
          return IqStanzaType.error;
        case 'set':
          return IqStanzaType.set;
        case 'result':
          return IqStanzaType.result;
        case 'get':
          return IqStanzaType.get;
        case 'invalid':
          return IqStanzaType.invalid;
        case 'timeout':
          return IqStanzaType.timeout;
      }
    }
    return IqStanzaType.invalid;
  }
}
