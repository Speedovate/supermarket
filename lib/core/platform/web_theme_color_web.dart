import 'dart:html' as html;

void syncAuthenticatedAdminTheme({required bool isAuthenticatedAdmin}) {
  html.window.dispatchEvent(
    html.CustomEvent(
      'andrews-authenticated-admin-theme',
      detail: isAuthenticatedAdmin,
    ),
  );
}
