// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool hasBrowserTextSelection() {
  final selection = html.window.getSelection();
  if (selection == null) {
    return false;
  }
  return selection.toString().trim().isNotEmpty;
}
