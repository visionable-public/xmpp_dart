import 'dart:async';
import 'dart:collection';

import 'package:xmpp_stone/src/connection.dart';
import 'package:xmpp_stone/src/account/xmpp_account_settings.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/features/binding_resource_negotiator.dart';
import 'package:xmpp_stone/src/features/negotiator.dart';
import 'package:xmpp_stone/src/features/session_initiation_negotiator.dart';
import 'package:xmpp_stone/src/features/start_tls_negotatior.dart';
import 'package:xmpp_stone/src/features/sasl/sasl_authentication_feature.dart';
import 'package:xmpp_stone/src/features/servicediscovery/carbons_negotiator.dart';
import 'package:xmpp_stone/src/features/servicediscovery/feature.dart';
import 'package:xmpp_stone/src/features/servicediscovery/mam_negotiator.dart';
import 'package:xmpp_stone/src/features/servicediscovery/service_discovery_negotiator.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xmpp_stone/src/features/streammanagement/stream_managment_module.dart';

import '../elements/nonzas/nonza.dart';
import '../logger/log.dart';
import 'negotiator.dart';
import 'servicediscovery/service_discovery_negotiator.dart';

class ConnectionNegotiatorManager {
  static const String tag = 'ConnectionNegotiatorManager';
  List<Negotiator> supportedNegotiatorList = [];
  Negotiator? activeNegotiator;
  Queue<NegotiatorWithSupportedNonzas?> waitingNegotiators =
      Queue<NegotiatorWithSupportedNonzas?>();

  final Connection _connection;
  final XmppAccountSettings _accountSettings;

  StreamSubscription<NegotiatorState>? activeSubscription;

  ConnectionNegotiatorManager(this._connection, this._accountSettings);

  void init() {
    supportedNegotiatorList.clear();
    _initSupportedNegotiatorList();
    waitingNegotiators.clear();
  }

  void negotiateFeatureList(xml.XmlElement element) {
    Log.d(tag, 'Negotiating features');
    var nonzas = element.descendants
        .whereType<xml.XmlElement>()
        .map((element) => Nonza.parse(element))
        .toList();
    for (var negotiator in supportedNegotiatorList) {
      var matchingNonzas = negotiator.match(nonzas);
      if (matchingNonzas != null && matchingNonzas.isNotEmpty) {
        waitingNegotiators
            .add(NegotiatorWithSupportedNonzas(negotiator, matchingNonzas));
      }
    }
    if (_connection.authenticated) {
      waitingNegotiators.add(NegotiatorWithSupportedNonzas(
          ServiceDiscoveryNegotiator.getInstance(_connection), []));
    }
    negotiateNextFeature();
  }

  void cleanNegotiators() {
    waitingNegotiators.clear();
    if (activeNegotiator != null) {
      activeNegotiator!.backToIdle();
      activeNegotiator = null;
    }
    if (activeSubscription != null) {
      activeSubscription!.cancel();
    }
  }

  void negotiateNextFeature() {
    var negotiatorWithData = pickNextNegotiator();
    if (negotiatorWithData != null) {
      activeNegotiator = negotiatorWithData.negotiator;
      activeNegotiator!.negotiate(negotiatorWithData.supportedNonzas);
      //TODO: this should be refactored
      if (activeSubscription != null) activeSubscription!.cancel();
      if (activeNegotiator != null) {
        Log.d(tag, 'ACTIVE FEATURE: ${negotiatorWithData.negotiator}');
      }

      try {
        activeSubscription =
            activeNegotiator!.featureStateStream.listen(stateListener);
      } catch (e) {
        // Stream has already been listened to this listener
      }
    } else {
      activeNegotiator = null;
      _connection.doneParsingFeatures();
    }
  }

  void _initSupportedNegotiatorList() {
    var streamManagement = StreamManagementModule.getInstance(_connection);
    streamManagement.reset();
    if (_connection.isTlsRequired()) {
      supportedNegotiatorList.add(StartTlsNegotiator(_connection)); //priority 1
    }
    supportedNegotiatorList
        .add(SaslAuthenticationFeature(_connection, _accountSettings.password));
    if (streamManagement.isResumeAvailable()) {
      supportedNegotiatorList.add(streamManagement);
    }
    supportedNegotiatorList
        .add(BindingResourceConnectionNegotiator(_connection));
    supportedNegotiatorList
        .add(streamManagement); //doesn't care if success it will be done
    supportedNegotiatorList.add(SessionInitiationNegotiator(_connection));
    // supportedNegotiatorList
    //     .add(ServiceDiscoveryNegotiator.getInstance(_connection));
    supportedNegotiatorList.add(CarbonsNegotiator.getInstance(_connection));
    supportedNegotiatorList.add(MAMNegotiator.getInstance(_connection));

  }

  void stateListener(NegotiatorState state) {
    if (state == NegotiatorState.negotiating) {
      Log.d(tag, 'Feature Started Parsing');
    } else if (state == NegotiatorState.doneCleanOthers) {
      cleanNegotiators();
    } else if (state == NegotiatorState.done) {
      negotiateNextFeature();
    }
  }

  NegotiatorWithSupportedNonzas? pickNextNegotiator() {
    if (waitingNegotiators.isEmpty) return null;
    var negotiatorWithData = waitingNegotiators.firstWhere((element) {
      Log.d(tag,
          'Found matching negotiator ${element!.negotiator.isReady().toString()}');
      return element.negotiator.isReady();
    }, orElse: () {
      Log.d(tag, 'No matching negotiator');
      return null;
    });
    waitingNegotiators.remove(negotiatorWithData);
    return negotiatorWithData;
  }

  void addFeatures(List<Feature> supportedFeatures) {
    Log.e(tag,
        'ADDING FEATURES count: ${supportedFeatures.length} $supportedFeatures');
    for (var negotiator in supportedNegotiatorList) {
      var matchingNonzas = negotiator.match(supportedFeatures);
      if (matchingNonzas != null && matchingNonzas.isNotEmpty) {
        Log.d(tag, 'Adding negotiator: $negotiator $matchingNonzas');
        waitingNegotiators
            .add(NegotiatorWithSupportedNonzas(negotiator, matchingNonzas));
      }
    }
  }
}

class NegotiatorWithSupportedNonzas {
  Negotiator negotiator;
  List<Nonza> supportedNonzas;

  NegotiatorWithSupportedNonzas(this.negotiator, this.supportedNonzas);
}
