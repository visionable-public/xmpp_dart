import 'package:xmpp_stone/src/roster/buddy.dart';

abstract class RosterListener {
  void onRosterListChanged(List<Buddy> roster);
}
