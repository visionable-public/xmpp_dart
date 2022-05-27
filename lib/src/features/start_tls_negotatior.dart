import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/features/negotiator.dart';

import '../elements/nonzas/nonza.dart';
import '../logger/log.dart';

class StartTlsNegotiator extends Negotiator {
  static const tag = 'StartTlsNegotiator';
  final Connection _connection;
  late StreamSubscription<Nonza> subscription;

  StartTlsNegotiator(this._connection) {
    expectedName = 'StartTlsNegotiator';
    expectedNameSpace = 'urn:ietf:params:xml:ns:xmpp-tls';
    priorityLevel = 1;
  }

  @override
  void negotiate(List<Nonza> nonza) {
    Log.d(tag, 'negotiating starttls');
    if(match(nonza).isNotEmpty) {
      state = NegotiatorState.negotiating;
      subscription = _connection.inNonzasStream.listen(checkNonzas);
      _connection.writeNonza(StartTlsResponse());
    }
  }

  void checkNonzas(Nonza nonza) {
    if (nonza.name == 'proceed') {
      _connection.startSecureSocket();
      state = NegotiatorState.doneCleanOthers;
      subscription.cancel();
    } else if (nonza.name == 'failure') {
      _connection.startTlsFailed();
    }
  }

  @override
  List<Nonza> match(List<Nonza> request) {
    var nonza = request.firstWhereOrNull(
        (request) => request.name == 'starttls' && request.getAttribute('xmlns')?.value == expectedNameSpace);
    return nonza != null ? [nonza] : [];
  }
}

class StartTlsResponse extends Nonza {
  StartTlsResponse() {
    name = 'starttls';
    addAttribute(XmppAttribute('xmlns', 'urn:ietf:params:xml:ns:xmpp-tls'));
  }
}
