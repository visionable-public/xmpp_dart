import 'package:xmpp_stone/src/data/jid.dart';

class Buddy {
  SubscriptionType? subscriptionType;

  String? name;

  Jid? accountJid;

  Jid? _jid;

  Jid? get jid => _jid;

  Buddy(Jid jid) {
    _jid = jid;
  }

  @override
  String toString() {
    return _jid!.fullJid!;
  }

  static SubscriptionType? typeFromString(String? typeString) {
    switch (typeString) {
      case 'none':
        return SubscriptionType.none;
      case 'to':
        return SubscriptionType.to;
      case 'from':
        return SubscriptionType.from;
      case 'both':
        return SubscriptionType.both;
    }
    return null;
  }
}

enum SubscriptionType { none, to, from, both }
