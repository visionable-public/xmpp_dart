import 'dart:async';

import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/features/sasl/abstract_sasl_handler.dart';
import 'package:xmpp_stone/src/features/sasl/sasl_authentication_feature.dart';

import '../../logger/log.dart';

class AnonymousHandler implements AbstractSaslHandler {
  static const tag = 'AnonymousHandler';

  final Connection _connection;
  late StreamSubscription<Nonza> subscription;
  final _completer = Completer<AuthenticationResult>();
  ScramStates _scramState = ScramStates.initial;

  final SaslMechanism _mechanism;

  String? _mechanismString;

  AnonymousHandler(this._connection, this._mechanism) {
    initMechanism();
  }

  @override
  Future<AuthenticationResult> start() {
    subscription = _connection.inNonzasStream.listen(_parseAnswer);
    sendInitialMessage();
    return _completer.future;
  }

  void initMechanism() {
    if (_mechanism == SaslMechanism.anonymous) {
      _mechanismString = 'ANONYMOUS';
    }
  }

  void sendInitialMessage() {
    var nonza = Nonza();
    nonza.name = 'auth';
    nonza.addAttribute(
        XmppAttribute('xmlns', 'urn:ietf:params:xml:ns:xmpp-sasl'));
    nonza.addAttribute(XmppAttribute('mechanism', _mechanismString));
    _scramState = ScramStates.authSent;
    _connection.writeNonza(nonza);
  }

  void _parseAnswer(Nonza nonza) {
    if (_scramState == ScramStates.authSent) {
      if (nonza.name == 'failure') {
        _fireAuthFailed('Auth Error in challenge');
      } else if (nonza.name == 'success') {
        subscription.cancel();
        _completer.complete(AuthenticationResult(true, ''));
      }
    }
  }

  void _fireAuthFailed(String message) {
    Log.e(tag, message);
    subscription.cancel();
    _completer.complete(AuthenticationResult(false, message));
  }
}

enum ScramStates {
  initial,
  authSent,
}
