import 'package:bluetest/ble/ble_device_connector.dart';
import 'package:bluetest/ble/ble_logger.dart';
import 'package:bluetest/ble/ble_scanner.dart';
import 'package:bluetest/ble/ble_status_monitor.dart';
import 'package:bluetest/ui/ble_status_screen.dart';
import 'package:bluetest/ui/device_list.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

late BleScanner scanner;
late BleLogger bleLogger;
late FlutterReactiveBle ble;
late BleStatusMonitor monitor;
late BleDeviceConnector connector;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ble = FlutterReactiveBle();
  bleLogger = BleLogger(ble: ble);
  monitor = BleStatusMonitor(ble);
  connector = BleDeviceConnector(
    ble: ble, logMessage: bleLogger.addToLog);
  scanner = BleScanner(
    ble: ble, logMessage: bleLogger.addToLog);

  //
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'BLE Demo'),
    );
  }

}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: StreamBuilder(
        stream: monitor.state,
        initialData: BleStatus.unknown,
        builder: (context, snapshot) {
          if (snapshot.data! == BleStatus.ready) {
            return const DeviceListScreen();
          } else {
            return BleStatusScreen(status: snapshot.data ?? BleStatus.unknown);
          }
        },
      ),
    );
  }
}
