class ZelpException implements Exception {
  ZelpException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$message (code=$code)';
}

class AuthenticationException extends ZelpException {
  AuthenticationException(super.message, {super.code});
}

class DeviceException extends ZelpException {
  DeviceException(super.message, {super.code});
}

/// User-facing message for [ZelpException], else [Object.toString].
String exceptionMessage(Object error) => error is ZelpException ? error.message : error.toString();
