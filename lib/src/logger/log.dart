import 'dart:developer';

class Log {
  static LogLevel logLevel = LogLevel.verbose;

  static bool logXmpp = true;

  static void v(String tag, String message) {
    if (logLevel.index <= LogLevel.verbose.index) {
      log('V/[$tag]: $message');
    }
  }

  static void d(String tag, String message) {
    if (logLevel.index <= LogLevel.debug.index) {
      log('D/[$tag]: $message');
    }
  }

  static void i(String tag, String message) {
    if (logLevel.index <= LogLevel.info.index) {
      log('I/[$tag]: $message');
    }
  }

  static void w(String tag, String message) {
    if (logLevel.index <= LogLevel.warning.index) {
      log('W/[$tag]: $message');
    }
  }

  static void e(String tag, String message) {
    if (logLevel.index <= LogLevel.error.index) {
      log('E/[$tag]: $message');
    }
  }

  static void xmppReceiving(String message) {
    if (logXmpp) {
      log('---Xmpp Receiving:---');
      log(message);
    }
  }

  static void xmppSending(String message) {
    if (logXmpp) {
      log('---Xmpp Sending:---');
      log(message);
    }
  }

}

enum LogLevel { verbose, debug, info, warning, error, off }