import 'package:bluetest/ble/ble_device_interactor.dart';
import 'package:bluetest/ble/ble_scanner.dart';
import 'package:bluetest/main.dart';
import 'package:bluetest/ui/device_detail/device_detail_screen.dart';
import 'package:bluetest/ui/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

// import 'device_detail/device_detail_screen.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) => _DeviceList();
}

class _DeviceList extends StatefulWidget {

  @override
  _DeviceListState createState() => _DeviceListState();
}

class _DeviceListState extends State<_DeviceList> {
  final List<DiscoveredDevice> _devices = [];
  final flutterReactiveBle = FlutterReactiveBle();

  @override
  void initState() {
    super.initState();

    BleDeviceInteractor(
      bleDiscoverServices: (deviceId) async {
        await ble.discoverAllServices(deviceId);
        return ble.getDiscoveredServices(deviceId);
      },
      logMessage: bleLogger.addToLog,
      readRssi: ble.readRssi,
    );
  }

  @override
  void dispose() {
    scanner.stopScan(); 
    super.dispose();
  }

  void _startScanning() {
    // FlutterReactiveBle 
    Uuid serviceId = Uuid.parse("0000fff0-0000-1000-8000-00805f9b34fb");
    flutterReactiveBle.scanForDevices(withServices: [serviceId], scanMode: ScanMode.lowLatency).listen((device) {
       final knownDeviceIndex = _devices.indexWhere((d) => d.id == device.id);
      if (knownDeviceIndex >= 0) {
        _devices[knownDeviceIndex] = device;
      } else {
        _devices.add(device);
      }
      setState(() {});
    }, onError: (e) {
      // print("Error $e");
      //code for handling error
    });

    // scanner.startScan([Uuid.parse("0000fff0-0000-1000-8000-00805f9b34fb")]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Scan for devices'),
        ),
        body: ListView.builder(
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            dynamic device = _devices[index];
            return ListTile(
              title: Text(
              device.name),
              subtitle: Text(
                """
                ${device.id}
                RSSI: ${device.rssi}
                ${device.connectable}
                """,
              ),
              // leading: const Icon(Icons.abc),
              onTap: () async {
                scanner.stopScan();
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceInfo(device: device),
                  ),
                );
              },
            );
          },
        // body: StreamBuilder(
        //   stream: scanner.state,
        //   initialData: const BleScannerState(
        //     discoveredDevices: [],
        //     scanIsInProgress: false
        //   ),
        //   builder: (context, snapshot) {
        //     if(snapshot.hasData) {
        //       return ListView.builder(
        //         itemCount: snapshot.data!.discoveredDevices.length,
        //         itemBuilder: (context, index) {
        //           dynamic device = snapshot.data!.discoveredDevices[index];
        //           return ListTile(
        //             title: Text(
        //             device.name),
        //             subtitle: Text(
        //               """
        //               ${device.id}
        //               RSSI: ${device.rssi}
        //               ${device.connectable}
        //               """,
        //             ),
        //             // leading: const Icon(Icons.abc),
        //             onTap: () async {
        //               scanner.stopScan();
        //               await Navigator.push<void>(
        //                 context,
        //                 MaterialPageRoute(
        //                   builder: (_) => DeviceInfo(device: device),
        //                 ),
        //               );
        //             },
        //           );
        //         },
        //       );
        //     }
        //     else if(snapshot.hasError) {
        //       return const Text("Oops!");
        //     }
        //     else if(!snapshot.hasData) {
        //       return const Text("No Devices yet");
        //     }
        //     else {
        //       return Container();
        //     }
        //   },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _startScanning,
          child: const Icon(Icons.abc),
        ), 
      );
}
