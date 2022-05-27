import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';

class ANonza extends Nonza {
  static String kNAME = 'a';
  static String kXMLNS = 'urn:xmpp:sm:3';

  static bool match(Nonza nonza) =>
      (nonza.name == kNAME && nonza.getAttribute('xmlns')!.value == kXMLNS);

  ANonza(int hValue) {
    name = kNAME;
    addAttribute(XmppAttribute('xmlns', kXMLNS));
    addAttribute(XmppAttribute('h', hValue.toString()));
  }
}
