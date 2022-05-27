import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';

class EnableNonza extends Nonza {
  static String kNAME = 'enable';
  static String kXMLNS = 'urn:xmpp:sm:3';

  static bool match(Nonza nonza) =>
      (nonza.name == kNAME && nonza.getAttribute('xmlns')!.value == kXMLNS);

  EnableNonza(bool resume) {
    name = kNAME;
    addAttribute(XmppAttribute('xmlns', 'urn:xmpp:sm:3'));
    if (resume) {
      addAttribute(XmppAttribute('resume', 'true'));
    }
  }
}
