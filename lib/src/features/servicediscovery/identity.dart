
import '../../elements/nonzas/nonza.dart';

class Identity extends Nonza {
  String? get category {
    return getAttribute('category')?.value;
  }

  String? get type {
    return getAttribute('type')?.value;
  }

  @override
  String get name {
    return getAttribute('name')?.value ?? 'INVALID';
  }
}
