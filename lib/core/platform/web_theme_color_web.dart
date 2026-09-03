import 'dart:js_interop';

import 'package:web/web.dart' as web;

void syncAuthenticatedAdminTheme({required bool isAuthenticatedAdmin}) {
  web.window.dispatchEvent(
    web.CustomEvent(
      'andrews-authenticated-admin-theme',
      web.CustomEventInit(detail: isAuthenticatedAdmin.toJS),
    ),
  );
}
