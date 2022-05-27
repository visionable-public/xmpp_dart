import 'package:xmpp_stone/src/elements/forms/field_element.dart';
import '../xmpp_attribute.dart';
import '../xmpp_element.dart';

class XElement extends XmppElement {
  XElement() {
    name = 'x';
  }

  XElement.build() {
    name = 'x';
    addAttribute(XmppAttribute('xmlns', 'jabber:x:data'));
  }

  void setType(FormType type) {
    addAttribute(
        XmppAttribute('type', type.toString().split('.').last.toLowerCase()));
  }

  void addField(FieldElement fieldElement) {
    addChild(fieldElement);
  }
}

enum FormType { form, submit, cancel, result }
