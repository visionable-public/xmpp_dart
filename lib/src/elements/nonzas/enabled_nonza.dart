import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';

class EnabledNonza extends Nonza {
  static String kNAME = 'enabled';
  static String kXMLNS = 'urn:xmpp:sm:3';

  static bool match(Nonza nonza) =>
      (nonza.name == kNAME && nonza.getAttribute('xmlns')!.value == kXMLNS);

  EnabledNonza() {
    name = kNAME;
  }
}
