import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/elements/nonzas/a_nonza.dart';
import 'package:xmpp_stone/src/elements/nonzas/enable_nonza.dart';
import 'package:xmpp_stone/src/elements/nonzas/enabled_nonza.dart';
import 'package:xmpp_stone/src/elements/nonzas/failed_nonza.dart';
import 'package:xmpp_stone/src/elements/nonzas/nonza.dart';
import 'package:xmpp_stone/src/elements/nonzas/r_nonza.dart';
import 'package:xmpp_stone/src/elements/nonzas/resume_nonza.dart';
import 'package:xmpp_stone/src/elements/nonzas/resumed_nonza.dart';
import 'package:xmpp_stone/src/elements/nonzas/sm_nonza.dart';
import 'package:xmpp_stone/src/features/streammanagement/stream_state.dart';

import '../../../xmpp_stone.dart';
import '../negotiator.dart';

class StreamManagementModule extends Negotiator {
  static const tag = 'StreamManagementModule';

  static Map<Connection, StreamManagementModule> instances = {};

  static StreamManagementModule getInstance(Connection connection) {
    var module = instances[connection];
    if (module == null) {
      module = StreamManagementModule(connection);
      instances[connection] = module;
    }
    return module;
  }

  static void removeInstance(Connection connection) {
    var instance = instances[connection];
    instance?.timer?.cancel();
    instance?.inNonzaSubscription?.cancel();
    instance?.outStanzaSubscription?.cancel();
    instance?.inNonzaSubscription?.cancel();
    instance?._xmppConnectionStateSubscription.cancel();
    instances.remove(connection);
  }

  StreamState streamState = StreamState();
  final Connection _connection;
  late StreamSubscription<XmppConnectionState> _xmppConnectionStateSubscription;
  StreamSubscription<AbstractStanza?>? inStanzaSubscription;
  StreamSubscription<AbstractStanza>? outStanzaSubscription;
  StreamSubscription<Nonza>? inNonzaSubscription;

  bool ackTurnedOn = true;
  Timer? timer;

  final StreamController<AbstractStanza> _deliveredStanzasStreamController = StreamController.broadcast();

  Stream<AbstractStanza> get deliveredStanzasStream {
    return _deliveredStanzasStreamController.stream;
  }

  void sendAckRequest() {
    if (ackTurnedOn) {
      _connection.writeNonza(RNonza());
    }
  }

  void parseAckResponse(String rawValue) {
    var lastDeliveredStanza = int.parse(rawValue);
    var shouldStay = streamState.lastSentStanza - lastDeliveredStanza;
    if (shouldStay < 0) shouldStay = 0;
    while (streamState.nonConfirmedSentStanzas.length > shouldStay) {
      var stanza = streamState.nonConfirmedSentStanzas.removeFirst() as AbstractStanza;
      if (ackTurnedOn) {
        _deliveredStanzasStreamController.add(stanza);
      }
      if (stanza.id != null) {
        Log.d(tag, 'Delivered: ${stanza.id}');
      } else {
        Log.d(tag, 'Delivered stanza without id ${stanza.name}');
      }
    }
  }

  StreamManagementModule(this._connection) {
    _connection.streamManagementModule = this;
    ackTurnedOn = _connection.account.ackEnabled;
    expectedName = 'StreamManagementModule';
    _xmppConnectionStateSubscription = _connection.connectionStateStream.listen((state) {
      if (state == XmppConnectionState.reconnecting) {
        backToIdle();
      }
      if (!_connection.isOpened() && timer != null) {
        timer!.cancel();
      }
      if (state == XmppConnectionState.closed) {
        streamState = StreamState();
        //state = XmppConnectionState.Idle;
      }
    });
  }

  @override
  List<Nonza> match(List<Nonza> request) {
    var nonza = request.firstWhereOrNull((request) => SMNonza.match(request));
    return nonza != null ? [nonza] : [];
  }

  //TODO: Improve
  @override
  void negotiate(List<Nonza> nonza) {
    if (nonza.isNotEmpty && SMNonza.match(nonza[0]) && _connection.authenticated) {
      state = NegotiatorState.negotiating;
      inNonzaSubscription = _connection.inNonzasStream.listen(parseNonza);
      if (streamState.isResumeAvailable()) {
        tryToResumeStream();
      } else {
        sendEnableStreamManagement();
      }
    }
  }

  @override
  bool isReady() {
    return super.isReady() &&
        (isResumeAvailable() || (_connection.fullJid.resource != null && _connection.fullJid.resource!.isNotEmpty));
  }

  void parseNonza(Nonza nonza) {
    if (state == NegotiatorState.negotiating) {
      if (EnabledNonza.match(nonza)) {
        handleEnabled(nonza);
      } else if (ResumedNonza.match(nonza)) {
        resumeState(nonza);
      } else if (FailedNonza.match(nonza)) {
        if (streamState.tryingToResume) {
          Log.d(tag, 'Resuming failed');
          streamState = StreamState();
          state = NegotiatorState.done;
          negotiatorStateStreamController = StreamController();
          state = NegotiatorState.idle; //we will try again
        } else {
          Log.d(tag, 'StreamManagmentFailed'); //try to send an error down to client
          state = NegotiatorState.done;
        }
      }
    } else if (state == NegotiatorState.done) {
      if (ANonza.match(nonza)) {
        parseAckResponse(nonza.getAttribute('h')!.value!);
      } else if (RNonza.match(nonza)) {
        sendAckResponse();
      }
    }
  }

  void parseOutStanza(AbstractStanza stanza) {
    streamState.lastSentStanza++;
    streamState.nonConfirmedSentStanzas.addLast(stanza);
  }

  void parseInStanza(AbstractStanza? stanza) {
    streamState.lastReceivedStanza++;
  }

  void handleEnabled(Nonza nonza) {
    streamState.streamManagementEnabled = true;
    var resume = nonza.getAttribute('resume');
    if (resume != null && resume.value == 'true') {
      streamState.streamResumeEnabled = true;
      streamState.id = nonza.getAttribute('id')!.value;
    }
    state = NegotiatorState.done;
    if (timer != null) {
      timer!.cancel();
    }
    timer = Timer.periodic(Duration(milliseconds: 5000), (Timer t) => sendAckRequest());
    outStanzaSubscription = _connection.outStanzasStream.listen(parseOutStanza);
    inStanzaSubscription = _connection.inStanzasStream.listen(parseInStanza);
  }

  void handleResumed(Nonza nonza) {
    parseAckResponse(nonza.getAttribute('h')!.value!);

    state = NegotiatorState.done;
    if (timer != null) {
      timer!.cancel();
    }
    timer = Timer.periodic(Duration(milliseconds: 5000), (Timer t) => sendAckRequest());
  }

  void sendEnableStreamManagement() => _connection.writeNonza(EnableNonza(_connection.account.smResumable));

  void sendAckResponse() => _connection.writeNonza(ANonza(streamState.lastReceivedStanza));

  void tryToResumeStream() {
    if (!streamState.tryingToResume) {
      _connection.writeNonza(ResumeNonza(streamState.id, streamState.lastReceivedStanza));
      streamState.tryingToResume = true;
    }
  }

  void resumeState(Nonza resumedNonza) {
    streamState.tryingToResume = false;
    state = NegotiatorState.doneCleanOthers;
    _connection.setState(XmppConnectionState.resumed);
    handleResumed(resumedNonza);
  }

  bool isResumeAvailable() => streamState.isResumeAvailable();

  void reset() {
    negotiatorStateStreamController = StreamController();
    backToIdle();
  }
}
