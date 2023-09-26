import 'package:flutter_control/control.dart';
import 'package:localino_live/localino_live.dart';

void main() {
  runApp(const MyApp());

  final g1 = Generic();
  final g2 = Generic((value) {});

  print('${g1.generic} x ${g2.generic}');
}

class Generic<T> {
  final Function(T)? callback;

  const Generic([this.callback]);

  Type get generic => T;
}

class UITheme extends ControlTheme {
  UITheme(super.context);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    ControlRoot.initControl(
      debug: true,
      localization: LocalinoLive.options(
        remoteSync: false,
      ),
      entries: {
        CounterControl: CounterControl(),
      },
      initAsync: () async {
        await Future.delayed(Duration(seconds: 1));
      },
    );

    return ControlRoot(
      theme: ThemeConfig<UITheme>(
        builder: (_) => UITheme(),
        themes: {
          Brightness.light: (theme) => ThemeData(
              primarySwatch:
                  (Control.get<CounterControl>()?.counter ?? 0) % 2 == 0
                      ? Colors.green
                      : Colors.red),
          Brightness.dark: (theme) => ThemeData(primarySwatch: Colors.orange),
        },
      ),
      states: [
        AppState.init
            .build((context) => InitLoader.of(builder: (_) => Container())),
        AppState.main.build((context) => MenuPage()),
        AppState.onboarding.build((context) => MyHomePage(title: 'Onboarding')),
      ],
      app: (setup, home) => MaterialApp(
        key: setup.key,
        title: 'Flutter Demo',
        home: home,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        ),
        theme: setup.theme,
        locale: setup.locale,
        supportedLocales: setup.supportedLocales,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
      onSetupChanged: (setup) async {
        Intl.defaultLocale = setup.locale.toString();
      },
    );
  }
}

class CounterControl extends BaseControl with NotifierComponent {
  final loading = LoadingControl();
  final counter2 = ActionControl.empty<int>();

  int counter = 0;

  void incrementCounter() {
    counter++;
    counter2.value = counter;
    notify();
  }
}

class MenuPage extends ControlWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NavigatorStack.menu(
        items: {
          NavItem(key: '1'): (_) => MyHomePage(title: 'Flutter Demo 1'),
          NavItem(key: '2'): (_) => MyHomePage(title: 'Flutter Demo 2'),
        },
      ),
    );
  }
}

class MyHomePage extends SingleControlWidget<CounterControl> with RouteControl, ThemeProvider {
  MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title +
            ' ${localization.locale}' +
            ' / ${PrefsProvider.instance.get(ThemeConfig.preference_key)}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times: ',
            ),
            LoadingBuilder(
              control: control.loading,
              initial: (_) => CaseWidget(
                activeCase: 'light',
                //PrefsProvider.instance.get(ThemeConfig.preference_key),
                builders: {
                  'light': (_) => CaseTest(),
                  'dark': (_) => Container(
                        color: theme.primaryColor,
                        child: Text('dark'),
                      ),
                },
                placeholder: (_) => Text('default'),
              ),
            ),
            CaseWidget(
              activeCase: 'light', //PrefsProvider.instance.get(ThemeConfig.preference_key),
              builders: {
                'light': (_) => Container(
                      color: theme.primaryColor,
                      child: Text('light'),
                    ),
                'dark': (_) => Container(
                      color: theme.primaryColor,
                      child: Text('dark'),
                    ),
              },
              placeholder: (_) => Text('default'),
            ),
            Container(
              color: theme.primaryColor,
              child: ControlBuilder(
                control: control,
                builder: (context, value) => Text(
                  '${control.counter}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ControlBuilder<int>(
                  control: control.counter2,
                  builder: (context, value) => Container(
                    color: theme.primaryColor,
                    child: Text(
                      '$value',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  noData: (_) => Text(
                    '---',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                SizedBox(
                  width: 32.0,
                ),
                ControlBuilder(
                  control: control.counter2,
                  builder: (context, value) => Container(
                    color: theme.primaryColor,
                    child: Text(
                      value is int ? '$value' : '---',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32.0,
                ),
                ControlBuilder<dynamic>(
                  control: control.counter2,
                  builder: (context, value) => Container(
                    color: theme.primaryColor,
                    child: Text(
                      value is int ? '$value' : '---',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32.0,
                ),
                ControlBuilder<CounterControl>(
                  control: control,
                  builder: (context, value) => Container(
                    color: theme.primaryColor,
                    child: Text(
                      value.counter > 0 ? '${value.counter}' : '---',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                ControlScope.root.setAppState(
                    ControlScope.root.state == AppState.main
                        ? AppState.onboarding
                        : AppState.main);
              },
              child: Text('${ControlScope.root.state}'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          //control.incrementCounter();
          theme.changeTheme(PrefsProvider.instance.get(ThemeConfig.preference_key) == 'light' ? Brightness.dark : Brightness.light);
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CaseTest extends StatelessWidget with LocalinoProvider {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context);

    return Container(
      color: theme.primaryColor,
      child: Text(localize('action_add_localization')),
    );
  }
}
