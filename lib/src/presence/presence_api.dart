import 'package:xmpp_stone/src/data/jid.dart';
import 'package:xmpp_stone/src/elements/stanzas/presence_stanza.dart';

abstract class PresenceApi {
  void sendPresence(PresenceData presence);

  void subscribe(Jid to);

  void unsubscribe(Jid to);

  void acceptSubscription(Jid to);

  void declineSubscription(Jid to);

  void sendDirectPresence(PresenceData presence, Jid to);

  void askDirectPresence(Jid to);
}

class PresenceData {
  PresenceShowElement? showElement;
  String? status;
  Jid? jid; // if Jid is Null or self jid its self presence
  PresenceData(this.showElement, this.status, this.jid);
}

enum SubscriptionEventType { request, accepted, declined }

class SubscriptionEvent {
  SubscriptionEventType? type;
  Jid? jid;
}

class PresenceErrorEvent {
  PresenceStanza? presenceStanza;
  PresenceErrorType? type;
}

enum PresenceErrorType { modify }
