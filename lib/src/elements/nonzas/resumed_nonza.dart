import '../xmpp_attribute.dart';
import 'nonza.dart';

class ResumedNonza extends Nonza {
  static String kNAME = 'resumed';
  static String kXMLNS = 'urn:xmpp:sm:3';

  static bool match(Nonza nonza) =>
      (nonza.name == kNAME && nonza.getAttribute('xmlns')!.value == kXMLNS);

  ResumedNonza() {
    name = kNAME;
    addAttribute(XmppAttribute('xmlns', kXMLNS));
  }
}