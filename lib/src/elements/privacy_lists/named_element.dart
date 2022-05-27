import '../xmpp_attribute.dart';
import '../xmpp_element.dart';

abstract class NamedElement extends XmppElement {
  void setName(String name) {
    addAttribute(XmppAttribute('name', name));
  }
}
