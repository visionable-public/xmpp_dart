class PrivacyListItem {
  PrivacyType? type;
  String? value;
  PrivacyAction action;
  int order = 0;
  List<PrivacyControlStanza>? controlStanzas;

  PrivacyListItem({
    this.type,
    this.value,
    required this.action,
    required this.order,
    List<PrivacyControlStanza>? controlStanzas,
  }) : controlStanzas = controlStanzas ?? [];
}

enum PrivacyType { jid, group, subscription }
enum PrivacyAction { allow, deny }
enum PrivacySubscriptionType { both, to, from }
enum PrivacyControlStanza { message, iq, presenceIn, presenceOut }
