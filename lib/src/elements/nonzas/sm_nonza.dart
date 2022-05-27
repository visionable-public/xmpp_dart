import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';

class SMNonza extends Nonza {
  static String kNAME = 'sm';
  static String kXMLNS = 'urn:xmpp:sm:3';

  static bool match(Nonza nonza) =>
      (nonza.name == kNAME && nonza.getAttribute('xmlns')!.value == kXMLNS);

  SMNonza() {
    name = kNAME;
  }
}
