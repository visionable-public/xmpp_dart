import '../../elements/nonzas/nonza.dart';

class Feature extends Nonza {

  Feature() {
    name = 'feature';
  }
  String? get xmppVar {
    return getAttribute('var')?.value;
  }
}
