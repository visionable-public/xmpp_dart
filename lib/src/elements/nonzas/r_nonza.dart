import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';

class RNonza extends Nonza {
  static String kNAME = 'r';
  static String kXMLNS = 'urn:xmpp:sm:3';

  static bool match(Nonza nonza) =>
      (nonza.name == kNAME && nonza.getAttribute('xmlns')!.value == kXMLNS);

  RNonza() {
    name = kNAME;
    addAttribute(XmppAttribute('xmlns', kXMLNS));
  }
}
