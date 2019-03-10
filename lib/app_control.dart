import 'dart:async';

import 'package:flutter_control/core.dart';

/// One of the root Widgets of App.
/// Initializes with GlobalKey and BuildContext of root Widgets (Scaffold is recommended).
/// AppControl can hold important objects to use them anywhere in App.
/// Custom localization is used here. For more info check AppLocalization class.
class AppControl extends InheritedWidget {
  /// Runtime Type of class.
  /// Used for custom class integration.
  static Type _accessType;

  /// Key of root State.
  final GlobalKey rootKey;

  /// Returns current locale.
  String get iso2Locale => localization(this)?.locale;

  /// returns nearest AppControl to given context.
  /// nullable
  static AppControl of(BuildContext context) {
    if (context == null) {
      return null;
    }

    final control = context.inheritFromWidgetOfExactType(_accessType);

    if (control != null) {
      return control;
    }

    return factory(context).getItem('control');
  }

  /// returns instance of AppFactory.
  /// context is currently ignored.
  /// nullable
  static AppFactory factory([dynamic context]) => AppFactory.of(context);

  /// returns instance of AppLocalization
  /// context is currently ignored
  /// nullable
  static AppLocalization localization([dynamic context]) => factory(context)?.getItem('localization');

  /// Default constructor
  AppControl({Key key, @required this.rootKey, @required ContextHolder contextHolder, String defaultLocale, List<LocalizationAsset> locales, Map<String, dynamic> entries, Map<Type, Getter> initializers, Widget child}) : super(key: key, child: child) {
    assert(rootKey != null);
    assert(contextHolder != null);

    _accessType = this.runtimeType;

    if (entries == null) {
      entries = Map<String, dynamic>();
    }

    if (locales == null || locales.isEmpty) {
      locales = List<LocalizationAsset>();
      locales.add(LocalizationAsset('en', null));
    }

    entries['control'] = this;
    entries['localization'] = AppLocalization(defaultLocale ?? locales[0].iso2Locale, locales);

    factory(this).init(items: entries, initializers: initializers);

    contextHolder.once((context) => localization(this).changeToSystemLocale(context));
  }

  /// Returns root context for given context
  /// A context of current Navigator
  BuildContext rootContext(BuildContext context) => Navigator.of(context).context;

  /// Changes localization of all sub widgets (typically whole app).
  /// It can take a while because localization is loaded from json file.
  Future<bool> changeLocale(String iso2Locale) async {
    return await localization(this)?.changeLocale(iso2Locale);
  }

  @override
  bool updateShouldNotify(AppControl oldWidget) {
    return iso2Locale != oldWidget.iso2Locale;
  }
}
