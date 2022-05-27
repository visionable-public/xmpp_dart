import 'package:xmpp_stone/src/elements/forms/x_element.dart';
import '../xmpp_attribute.dart';
import '../xmpp_element.dart';

class QueryElement extends XmppElement{
  QueryElement() {
    name = 'query';
  }

  void addX(XElement xElement) {
    addChild(xElement);
  }

  void setXmlns(String xmlns) {
    addAttribute(XmppAttribute('xmlns', xmlns));
  }

  void setQueryId(String queryId) {
    XmppAttribute('queryid', queryId);
  }

  String? get queryId => getAttribute('queryid')?.value;
}