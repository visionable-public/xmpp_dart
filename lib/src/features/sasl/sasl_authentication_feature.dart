import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/features/negotiator.dart';
import 'package:xmpp_stone/src/features/sasl/abstract_sasl_handler.dart';
import 'package:xmpp_stone/src/features/sasl/plain_sasl_handler.dart';
import 'package:xmpp_stone/src/features/sasl/scram_sasl_handler.dart';
import 'package:xmpp_stone/src/features/sasl/anonymous_handler.dart';

import '../../elements/nonzas/nonza.dart';

class SaslAuthenticationFeature extends Negotiator {
  final Connection _connection;
  final String _password;

  final Set<SaslMechanism> _offeredMechanisms = {};
  final Set<SaslMechanism> _supportedMechanisms = {};

  SaslAuthenticationFeature(this._connection, this._password) {
    _supportedMechanisms.add(SaslMechanism.scramSHA1);
    _supportedMechanisms.add(SaslMechanism.scramSHA256);
    _supportedMechanisms.add(SaslMechanism.plain);
    _supportedMechanisms.add(SaslMechanism.anonymous);
    expectedName = 'SaslAuthenticationFeature';
  }

  // improve this
  @override
  List<Nonza> match(List<Nonza> request) {
    var nonza = request.firstWhereOrNull((element) => element.name == 'mechanisms');
    return nonza != null ? [nonza] : [];
  }

  @override
  void negotiate(List<Nonza> nonza) {
    if (nonza.isNotEmpty) {
      _populateOfferedMechanism(nonza[0]);
      _process();
    }
  }

  void _process() {
    var mechanism = _supportedMechanisms.firstWhere(
        (mch) => _offeredMechanisms.contains(mch),
        orElse: _handleAuthNotSupported);
    AbstractSaslHandler? saslHandler;
    switch (mechanism) {
      case SaslMechanism.plain:
        saslHandler = PlainSaslHandler(_connection, _password);
        break;
      case SaslMechanism.scramSHA256:
      case SaslMechanism.scramSHA1:
        saslHandler = ScramSaslHandler(_connection, _password, mechanism);
        break;
      case SaslMechanism.scramSHA1Plus:
        break;
      case SaslMechanism.external:
        break;
      case SaslMechanism.anonymous:
        saslHandler = AnonymousHandler(_connection, mechanism);
        break;
      case SaslMechanism.notSupported:
        break;
    }
    if (saslHandler != null) {
      state = NegotiatorState.negotiating;
      saslHandler.start().then((result) {
        if (result.successful) {
          _connection.setState(XmppConnectionState.authenticated);
        } else {
          _connection.setState(XmppConnectionState.authenticationFailure);
          _connection.errorMessage = result.message;
          _connection.close();
        }
        state = NegotiatorState.done;
      });
    }
  }

  void _populateOfferedMechanism(Nonza nonza) {
    nonza.children
        .where((element) => element.name == 'mechanism')
        .forEach((mechanism) {
      switch (mechanism.textValue) {
        case 'EXTERNAL':
          _offeredMechanisms.add(SaslMechanism.external);
          break;
        case 'SCRAM-SHA-1-PLUS':
          _offeredMechanisms.add(SaslMechanism.scramSHA1Plus);
          break;
        case 'SCRAM-SHA-256':
          _offeredMechanisms.add(SaslMechanism.scramSHA256);
          break;
        case 'SCRAM-SHA-1':
          _offeredMechanisms.add(SaslMechanism.scramSHA1);
          break;
        case 'ANONYMOUS':
          _offeredMechanisms.add(SaslMechanism.anonymous);
          break;
        case 'PLAIN':
          _offeredMechanisms.add(SaslMechanism.plain);
          break;
      }
    });
  }

  SaslMechanism _handleAuthNotSupported() {
    _connection.setState(XmppConnectionState.authenticationNotSupported);
    _connection.close();
    state = NegotiatorState.done;
    return SaslMechanism.notSupported;
  }
}

enum SaslMechanism {
  external,
  scramSHA1Plus,
  scramSHA1,
  scramSHA256,
  plain,
  anonymous,
  notSupported
}
