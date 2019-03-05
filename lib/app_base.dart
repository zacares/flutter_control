import 'package:flutter_control/core.dart';

typedef OnContextChanged = Function(BuildContext context);

/// Main(root) Widget for whole app.
/// AppControl and root Scaffold is build in State.
/// This Widget helps easily integrate AppControl as InheritedWidget into application.
/// Currently supports only MaterialApp.
/// /// Structure: AppControl -> MaterialApp -> Scaffold -> Your Content (root - BaseController).
class BaseApp extends StatefulWidget {
  final String title;
  final ThemeData theme;
  final List<LocalizationAsset> locales;
  final BaseController root;
  final Map<String, dynamic> entries;
  final String defaultLocale;

  /// Root GlobalKey of default Scaffold.
  /// Is passed into AppControl.
  final rootKey = GlobalKey<State<BaseApp>>();

  /// Root BuildContext of default Scaffold.
  /// Is passed into AppControl.
  final contextHolder = ContextHolder();

  /// Default constructor
  BaseApp({this.title, this.theme, this.defaultLocale, this.locales, @required this.root, this.entries});

  @override
  State<StatefulWidget> createState() => BaseAppState();
}

/// Creates State for BaseApp.
/// AppControl and root Scaffold is build here.
/// This State is used as root GlobalKey.
/// BuildContext from Scaffold is used as root context.
/// Structure: AppControl -> MaterialApp -> Scaffold -> Your Content (root - BaseController).
class BaseAppState extends State<BaseApp> {
  @override
  Widget build(BuildContext context) {
    return AppControl(
      rootKey: widget.rootKey,
      contextHolder: widget.contextHolder,
      defaultLocale: widget.defaultLocale,
      locales: widget.locales,
      entries: widget.entries,
      child: MaterialApp(
        title: widget.title,
        theme: widget.theme,
        home: Scaffold(
          key: widget.rootKey,
          body: Builder(builder: (ctx) {
            widget.contextHolder.changeContext(ctx);
            return widget.root.init().getWidget(forceInit: true);
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    widget?.contextHolder?.dispose();
  }
}

/// Holds BuildContext and notifies if changed.
class ContextHolder implements Disposable {
  /// Current context.
  /// Can be changed later.
  BuildContext _context;

  /// Returns current context.
  BuildContext get context => _context;

  /// On context changed listener.
  OnContextChanged _onContextChanged;

  /// Notify just once on context changed listener.
  OnContextChanged _onContextChangedOnce;

  /// Initializes ContextHolder with default context.
  ContextHolder({BuildContext context}) {
    _context = context;
  }

  /// Changes current context.
  void changeContext(BuildContext context) {
    _context = context;

    if (_onContextChanged != null) {
      _onContextChanged(context);
    }

    if (_onContextChangedOnce != null) {
      _onContextChangedOnce(context);
      _onContextChangedOnce = null;
    }
  }

  /// Subscribe listener for context changes.
  void subscribe(OnContextChanged onContextChanged, {bool instantNotify: false}) {
    _onContextChanged = onContextChanged;

    if (instantNotify && context != null) {
      changeContext(context);
    }
  }

  /// Subscribe listener just of one context change.
  void once(OnContextChanged onContextChanged) {
    if (context != null) {
      onContextChanged(context);
    } else {
      _onContextChangedOnce = onContextChanged;
    }
  }

  @override
  void dispose() {
    _onContextChanged = null;
    _context = null;
  }
}
