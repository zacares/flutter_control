part of flutter_control;

/// Holds arguments from Widget and State.
/// Helps to transfer arguments between Widget Tree rebuilds and resurrection of State.
class ControlArgHolder implements Disposable {
  /// Manually updated validity. Mostly corresponds to [State] availability.
  bool _valid = true;

  /// Holds args when [State] disposes and [Widget] goes off screen.
  ControlArgs? _cache;

  /// Current [State] of [Widget].
  CoreState? _state;

  /// Returns current [State] of [Widget].
  CoreState? get state => _state;

  /// Checks if [Widget] with current [State] is valid.
  bool get isValid => _valid;

  /// Checks if arguments cache is used and [State] is not currently available.
  bool get isCacheActive => _cache != null;

  /// Checks if [State] is available.
  bool get initialized => _state != null;

  /// Current args of [Widget] and [State].
  Map get args => argStore.data;

  /// [ControlArgs] that holds current args of [Widget] and [State].
  ControlArgs get argStore =>
      _state?.args ?? _cache ?? (_cache = ControlArgs());

  /// Initializes holder with given [state].
  /// [args] are smoothly transferred between State and Cache based on current Widget lifecycle.
  void init(CoreState? state) {
    _state = state;
    _valid = true;

    if (_cache != null) {
      argStore.set(_cache);
      _cache = null;
    }
  }

  /// Returns all [ControlModel]s from internal args - [ControlArgs].
  /// If none found, empty List is returned.
  List<ControlModel> findControls() => argStore.getAll<ControlModel>();

  /// Copy corresponding State and args from [oldHolder].
  void copy(ControlArgHolder oldHolder) {
    if (oldHolder.initialized) {
      init(oldHolder.state);
    }

    argStore.set(oldHolder.argStore);
  }

  @override
  void dispose() {
    _cache = argStore;
    _valid = false;
    _state = null;
  }
}

/// Base abstract Widget that controls [State], stores [args] and keeps Widget/State in harmony though lifecycle of Widget.
/// [CoreWidget] extends [StatefulWidget] and completely solves [State] specific flow. This solution helps to use it like [StatelessWidget], but with benefits of [StatefulWidget].
///
/// This Widget comes with [TickerControl] and [SingleTickerControl] mixin to create [Ticker] and provide access to [vsync]. Then use [ControlModel] with [TickerComponent] to get access to [TickerProvider].
///
/// [ControlWidget] - Can subscribe to multiple [ControlModel]s and is typically used for Pages and complex Widgets.
abstract class CoreWidget extends StatefulWidget
    implements Initializable, Disposable {
  final holder = ControlArgHolder();

  ControlScope get scope => ControlScope.of(this);

  /// Returns 'true' if [State] is hooked and [WidgetControlHolder] is initialized.
  bool get isInitialized => holder.initialized;

  /// Returns 'true' if [Widget] is active and [WidgetControlHolder] is not disposed.
  /// Widget is valid even when is not initialized yet.
  bool get isValid => holder.isValid;

  /// Returns [BuildContext] of current [State] if is available.
  BuildContext? get context => holder.state?.context;

  /// Base Control Widget that handles [State] flow.
  /// [args] - Arguments passed to this Widget and also to [ControlModel]s.
  ///
  /// Check [ControlWidget] and [StateboundWidget].
  CoreWidget({super.key, dynamic args}) {
    holder.argStore.set(args);
  }

  @override
  @protected
  @mustCallSuper
  void init(Map args) => addArg(args);

  @protected
  void onInit(Map args) {}

  /// Updates holder with arguments and checks if is [State] valid.
  /// Returns 'true' if [State] of this Widget is OK.
  bool _updateHolder(CoreWidget oldWidget) {
    holder.copy(oldWidget.holder);

    return !holder.initialized;
  }

  /// Called whenever Widget needs update.
  /// Check [State.didUpdateWidget] for more info.
  void onUpdate(CoreWidget oldWidget) {}

  /// Executed when [State] is changed and new [state] is available.
  /// Widget will try to resurrect State and injects args from 'cache' in [holder].
  @protected
  @mustCallSuper
  void onStateUpdate(CoreWidget oldWidget, CoreState state) {
    _notifyHolder(state);
  }

  /// Initializes and sets given [state].
  @protected
  void _notifyHolder(CoreState state) {
    assert(() {
      if (holder.initialized && holder.state != state) {
        printDebug('state re-init of: ${this.runtimeType.toString()}');
        printDebug('old state: ${holder.state}');
        printDebug('new state: $state');
      }
      return true;
    }());

    if (holder.state == state) {
      return;
    }

    holder.init(state);
  }

  /// Called whenever dependency of Widget is changed.
  /// Check [State.didChangeDependencies] for more info.
  @protected
  void onDependencyChanged() {}

  /// Returns [BuildContext] of this [Widget] or 'root' context from [ControlRootScope].
  BuildContext? getContext({bool root = false}) =>
      root ? ControlScope.root.context ?? context : context;

  /// Returns [ControlModel] by given [T] or [key] from current UI Tree
  T? getScopeControl<T extends ControlModel?>({dynamic key, dynamic args}) =>
      scope.get<T>(key: key, args: args);

  /// Adds given [args] to this Widget's internal arg store.
  /// [args] can be whatever - [Map], [List], [Object], or any primitive.
  ///
  /// Check [setArg] for more 'set' options.
  /// Internally uses [ControlArgs]. Check [ControlArgs.set].
  /// Use [holder.argStore] to get raw access to [ControlArgs].
  void addArg(dynamic args) => holder.argStore.set(args);

  /// Adds given [args] to this Widget's internal arg store.
  /// [args] can be whatever - [Map], [List], [Object], or any primitive.
  ///
  /// Internally uses [ControlArgs]. Check [ControlArgs.set].
  /// Use [holder.argStore] to get raw access to [ControlArgs].
  void setArg<T>({dynamic key, required dynamic value}) =>
      holder.argStore.add<T>(key: key, value: value);

  /// Returns value by given [key] and [Type] from this Widget's internal arg store.
  ///
  /// Internally uses [ControlArgs]. Check [ControlArgs.get].
  /// Use [holder.argStore] to get raw access to [ControlArgs].
  T? getArg<T>({dynamic key, T? defaultValue}) =>
      holder.argStore.get<T>(key: key, defaultValue: defaultValue);

  /// Returns value by given [key] and [Type] from this Widget's internal arg store.
  /// If object is not found, then widget will [init] and store it to args.
  /// Object is also registered for dispose.
  ///
  /// Internally uses [ControlArgs]. Check [ControlArgs.getOrInit].
  /// Use [holder.argStore] to get raw access to [ControlArgs].
  T? mount<T>({dynamic key, T Function()? init, bool stateNotifier = false}) {
    final value = holder.argStore.getOrInit<T>(key: key, defaultValue: init);

    if (value is Disposable) {
      if (stateNotifier) {
        registerStateNotifier(value);
      } else {
        register(value);
      }
    }

    return value;
  }

  /// Removes given [arg] from this Widget's internal arg store.
  ///
  /// Internally uses [ControlArgs]. Check [ControlArgs.remove].
  /// Use [getArgStore] to get raw access to [ControlArgs].
  void removeArg<T>({dynamic key}) => holder.argStore.remove<T>(key: key);

  /// Registers object to lifecycle of [State].
  ///
  /// Widget with State must be initialized before executing this function - check [isInitialized].
  /// It's safe to register objects in/after [onInit] function.
  @protected
  void register(Disposable? object) {
    assert(isInitialized);

    holder.state!.register(object);
  }

  @protected
  void unregister(Disposable? object) {
    assert(isInitialized);

    holder.state!.unregister(object);
  }

  @protected
  void registerStateNotifier(dynamic object) {
    if (object is ObservableValue) {
      register(object.subscribe((value) => notifyState()));
    } else if (object is ObservableChannel) {
      register(object.subscribe(() => notifyState()));
    } else if (object is Listenable) {
      final callback = () => notifyState();
      object.addListener(callback);
      register(DisposableClient(parent: object)
        ..onDispose = () => object.removeListener(callback));
    } else if (object is Stream) {
      register(FieldControl.of(object).subscribe((value) => notifyState()));
    } else if (object is Future) {
      register((FieldControl()..onFuture(object))
          .subscribe((value) => notifyState()));
    }
  }

  @protected
  void notifyState() => holder.state!.notifyState();

  @override
  void dispose() {}
}

/// [State] of [CoreWidget].
abstract class CoreState<T extends CoreWidget> extends State<T> {
  /// Args used via [ControlArgHolder].
  ControlArgs? _args;

  /// Args used via [ControlArgHolder].
  ControlArgs get args => _args ?? (_args = ControlArgs());

  /// Checks is State is initialized and [CoreWidget.onInit] is called just once.
  bool _stateInitialized = false;

  /// Checks if State is initialized and dependencies are set.
  bool get isInitialized => _stateInitialized;

  /// Checks if [Element] is 'dirty' and needs rebuild.
  bool get isDirty => (context as Element).dirty;

  /// Objects to dispose with State.
  List<Disposable?>? _objects;

  /// Registers object to dispose with this State.
  void register(Disposable? object) {
    if (_objects == null) {
      _objects = <Disposable?>[];
    }

    if (!_objects!.contains(object)) {
      if (object is ReferenceCounter) {
        object.addReference(this);
      }

      _objects!.add(object);
    }
  }

  /// Unregisters object to dispose from this State.
  void unregister(Disposable? object) {
    _objects?.remove(object);

    if (object is ReferenceCounter) {
      object.removeReference(this);
    }
  }

  @override
  @mustCallSuper
  void initState() {
    super.initState();

    widget._notifyHolder(this);
  }

  void notifyState() {
    if (isDirty) {
      // TODO: no need to set state.. set state next frame ?
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_stateInitialized) {
      _stateInitialized = true;
      widget.onInit(_args!.data);
    }

    widget.onDependencyChanged();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);

    final updateState = widget._updateHolder(oldWidget);

    widget.onUpdate(oldWidget);

    if (updateState) {
      widget.onStateUpdate(oldWidget, this);
    }
  }

  @override
  void dispose() {
    super.dispose();

    _stateInitialized = false;
    widget.holder.dispose();

    _objects?.forEach((element) {
      if (element is DisposeHandler) {
        element.requestDispose(this);
      } else {
        element!.dispose();
      }
    });

    _objects = null;

    widget.dispose();
  }
}

abstract class ValueState<T extends StatefulWidget, U> extends State<T> {
  /// Checks if [Element] is 'mounted' or 'dirty' and marked for rebuild.
  bool get isDirty => !mounted || ((context as Element).dirty);

  /// Current value of state.
  U? value;

  void notifyValue(U? value) {
    if (isDirty) {
      this.value = value;
    } else {
      setState(() {
        this.value = value;
      });
    }
  }
}

/// Debug printer of [CoreWidget] lifecycle.
mixin CoreWidgetDebugPrinter on CoreWidget {
  @override
  void init(Map args) {
    printDebug('CORE $this: init --- $args');
    super.init(args);
  }

  @override
  void onInit(Map args) {
    printDebug('CORE $this: on init --- $args');
    super.onInit(args);
  }

  @override
  void onUpdate(CoreWidget oldWidget) {
    printDebug('CORE $this: on update --- $oldWidget');
    super.onUpdate(oldWidget);
  }

  @override
  void onStateUpdate(CoreWidget oldWidget, CoreState<CoreWidget> state) {
    printDebug('CORE $this: on state update --- $oldWidget | $state');
    super.onStateUpdate(oldWidget, state);
  }

  @override
  void onDependencyChanged() {
    printDebug('CORE $this: dependency changed');
    super.onDependencyChanged();
  }

  @override
  void dispose() {
    printDebug('CORE $this: dispose');
    super.dispose();
  }
}
