import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';

class FailedNonza extends Nonza {
  static String kNAME = 'failed';
  static String kXMLNS = 'urn:xmpp:sm:3';

  static bool match(Nonza nonza) =>
      (nonza.name == kNAME && nonza.getAttribute('xmlns')!.value == kXMLNS);

  FailedNonza() {
    name = kNAME;
  }
}
