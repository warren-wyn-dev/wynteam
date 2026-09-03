import 'dart:async';

/// The message to show for a failed request: a connectivity-specific one
/// when the request never reached a server, otherwise [serverMessage].
///
/// Every failure in this app used to read the same -- "โหลด X ไม่สำเร็จ"
/// -- whether WYNOS was down or the user had simply walked into a lift.
/// Those are different problems with different fixes, and only one of
/// them is the app's fault; telling someone with no signal that the
/// content failed to load invites them to blame the app for something a
/// moment's patience would fix.
///
/// Deliberately conservative: anything not clearly a transport failure
/// falls through to [serverMessage]. Wrongly telling someone their
/// connection is down when the server did answer -- with a real error --
/// is its own kind of misleading.
String errorMessageFor(Object error, {required String serverMessage}) =>
    isNetworkError(error) ? networkErrorMessage : serverMessage;

/// Shown when the request never made it to a server.
const networkErrorMessage = 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ลองใหม่อีกครั้ง';

/// Whether [error] means "the request never reached a server", as
/// opposed to "a server answered, and the answer was a failure".
///
/// Matched by name rather than by type on purpose. The type differs by
/// platform -- native throws `dart:io`'s SocketException/HttpException,
/// web has no sockets and surfaces the same conditions as
/// `package:http`'s ClientException -- and this app ships to both from
/// one codebase. Importing `dart:io` here would break the web build
/// outright (that library does not exist on web), and importing
/// `package:http` would mean declaring a dependency the app only has
/// transitively, through supabase_flutter. Name matching costs a little
/// precision and keeps one helper working on every target.
///
/// Supabase also wraps some transport failures rather than rethrowing
/// them, which the message-text checks below catch.
bool isNetworkError(Object error) {
  if (error is TimeoutException) return true;

  final type = error.runtimeType.toString();
  if (type == 'SocketException' ||
      type == 'HttpException' ||
      type == 'ClientException') {
    return true;
  }

  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection closed') ||
      text.contains('connection refused') ||
      text.contains('connection timed out') ||
      text.contains('network is unreachable') ||
      text.contains('xmlhttprequest error');
}
