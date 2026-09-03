import 'dart:js_interop';

@JS('__setAuthenticatedAdminTheme')
external void _setAuthenticatedAdminTheme(bool isAuthenticatedAdmin);

void syncAuthenticatedAdminTheme({required bool isAuthenticatedAdmin}) {
  _setAuthenticatedAdminTheme(isAuthenticatedAdmin);
}
