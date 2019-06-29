import 'dart:async';

import 'package:flutter_control/core.dart';

class WidgetStateHolder implements Disposable {
  bool initialized = false;
  ControlState state;
  List<BaseController> controllers;

  @override
  void dispose() {
    state = null;
    controllers = null;
  }
}

/// Base [StatefulWidget] to cooperate with [BaseController].
/// [BaseController]
/// [StateController]
///
/// [RouteControl] & [RouteController]
/// [RouteHandler] & [PageRouteProvider]
///
/// [AppFactory]
/// [AppControl]
/// [AppLocalization]
///
/// [ControlState]
/// [ControlTickerState]
/// [ControlSingleTickerState]
//TODO: get performance
abstract class ControlWidget extends StatefulWidget implements Initializable, Disposable {
  final holder = WidgetStateHolder();

  @protected
  ControlState get state => holder?.state;

  List<BaseController> get controllers => holder?.controllers;

  /// Widget don't have native access to BuildContext.
  BuildContext get context => state?.context;

  /// instance of [AppFactory].
  @protected
  AppFactory get factory => AppFactory.of(this);

  /// instance of [AppControl].
  @protected
  AppControl get control => AppControl.of(context);

  /// instance of [Device].
  /// Helper for [MediaQuery].
  @protected
  Device get device => Device(MediaQuery.of(context));

  /// instance of nearest [ThemeData].
  @protected
  ThemeData get theme => Theme.of(context);

  /// instance of [AppLocalization].
  AppLocalization get _localization => AppControl.localization(context);

  /// Default constructor
  ControlWidget({Key key}) : super(key: key) {
    _initHolder();
  }

  void _initHolder() {
    if (!holder.initialized) {
      holder.initialized = true;
      holder.controllers = onConstruct()?.where((item) => item != null)?.toList();
    }
  }

  /// Called during construction phase.
  /// Returned controllers will be notified during Widget/State initialization.
  @protected
  List<BaseController> onConstruct();

  @override
  ControlState<ControlWidget> createState() => ControlState();

  /// Returns context of this widget or [root] context that is stored in [AppControl]
  BuildContext getContext({bool root: false}) => root ? control.rootContext ?? context : context;

  /// When [RouteHandler] is used, then this function is called right after Widget construction. +
  /// All controllers (from [onConstruct]) are initialized too.
  @override
  @protected
  @mustCallSuper
  void init(Map args) {
    controllers?.forEach((controller) {
      controller.init(args);
    });
  }

  /// Called during State initialization.
  /// All controllers (from [onConstruct]) are subscribed to this Widget and given State.
  @protected
  @mustCallSuper
  void onInitState(ControlState state) {
    controllers?.forEach((controller) {
      controller.subscribe(this);
      controller.subscribe(state);

      if (controller is AnimationInitializer && state is TickerProvider) {
        (controller as AnimationInitializer).onTickerInitialized(state as TickerProvider);
      }

      if (controller is StateController) {
        state._createSub(controller);
        controller.onStateInitialized();
      }
    });
  }

  T getController<T>() => factory.find<T>(controllers);

  /// [StatelessWidget.build]
  /// [StatefulWidget.build]
  @protected
  Widget build(BuildContext context);

  /// Tries to localize text by given key.
  /// Localization is part of AppControl.
  @protected
  String localize(String key) => _localization?.localize(key) ?? '';

  /// Tries to localize text by given key.
  /// Localization is part of AppControl.
  @protected
  String extractLocalization(Map field) => _localization?.extractLocalization(field) ?? '';

  /// Disposes and removes all controllers (from [onConstruct]).
  /// Controller can prevent disposing [BaseController.preventDispose].
  @override
  @mustCallSuper
  void dispose() {
    printDebug("dispose ${this.toString()}");

    controllers?.forEach((controller) {
      if (!controller.preventDispose) {
        controller.dispose();
      }
    });

    holder.dispose();
  }
}

/// [ControlWidget] with [ControlTickerState]
abstract class ControlTickerWidget extends ControlWidget {
  ControlTickerWidget({Key key}) : super(key: key);

  @protected
  TickerProvider get ticker => holder.state as TickerProvider;

  @override
  ControlState<ControlWidget> createState() => ControlTickerState();
}

/// [ControlWidget] with [ControlSingleTickerState]
abstract class ControlSingleTickerWidget extends ControlWidget {
  ControlSingleTickerWidget({Key key}) : super(key: key);

  @protected
  TickerProvider get ticker => holder.state as TickerProvider;

  @override
  ControlState<ControlWidget> createState() => ControlSingleTickerState();
}

/// Base State for ControlWidget and StateController
/// State is subscribed to Controller which notifies back about state changes.
class ControlState<U extends ControlWidget> extends State<U> implements StateNotifier {
  /// List of Subscriptions from [StateController]s
  List<ControlSubscription> _stateSubs;

  @override
  void initState() {
    super.initState();

    widget.onInitState(this);
    widget.holder.state = this;
  }

  @override
  void notifyState([state]) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    widget.holder.state = this;

    return widget.build(context);
  }

  void _createSub(StateController controller) {
    if (_stateSubs == null) {
      _stateSubs = List<ControlSubscription>();
    }

    _stateSubs.add(controller.subscribeStateNotifier(notifyState));
  }

  /// Disposes Widget.
  @override
  @mustCallSuper
  void dispose() {
    super.dispose();

    if (_stateSubs != null) {
      _stateSubs.forEach((sub) => sub.cancel());
      _stateSubs.clear();
    }

    widget.dispose();
  }
}

/// [ControlState] with [TickerProviderStateMixin]
class ControlTickerState<U extends ControlWidget> extends ControlState<U> with TickerProviderStateMixin {}

/// [ControlState] with [SingleTickerProviderStateMixin]
class ControlSingleTickerState<U extends ControlWidget> extends ControlState<U> with SingleTickerProviderStateMixin {}

/// Mixin class to enable navigation for [ControlWidget]
mixin RouteControl on ControlWidget implements RouteNavigator {
  @override
  Future<dynamic> openRoute(Route route, {bool root: false, bool replacement: false}) {
    if (replacement) {
      return Navigator.of(context).pushReplacement(route);
    } else {
      return Navigator.of(getContext(root: root)).push(route);
    }
  }

  @override
  Future<dynamic> openRoot(Route route) {
    return Navigator.of(context).pushAndRemoveUntil(route, (pop) => false);
  }

  @override
  Future<dynamic> openDialog(WidgetBuilder builder, {bool root: false, DialogType type: DialogType.popup}) async {
    final dialogContext = getContext(root: root);

    switch (type) {
      case DialogType.popup:
        return await showDialog(context: dialogContext, builder: (context) => builder(context));
      case DialogType.sheet:
        return await showModalBottomSheet(context: dialogContext, builder: (context) => builder(context));
      case DialogType.dialog:
        return await Navigator.of(dialogContext).push(MaterialPageRoute(builder: (BuildContext context) => builder(context), fullscreenDialog: true));
      case DialogType.dock:
        return showBottomSheet(context: dialogContext, builder: (context) => builder(context));
    }

    return null;
  }

  @override
  void backTo(String routeIdentifier) {
    Navigator.of(context).popUntil((route) => route.settings.name == routeIdentifier);
  }

  @override
  void backToRoot() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void close([dynamic result]) {
    Navigator.of(context).pop(result);
  }
}
