import 'browser_text_selection_stub.dart'
    if (dart.library.html) 'browser_text_selection_web.dart' as impl;

bool hasBrowserTextSelection() => impl.hasBrowserTextSelection();
