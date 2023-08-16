import 'dart:developer';

void logError(String message, [String? code]) {
  if (code != null) {
    log('Error: $code\nError Message: $message', name: "Face Camera");
  } else {
    log('Error: $code', name: "Face Camera");
  }
}
