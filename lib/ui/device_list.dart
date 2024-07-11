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
    scanner.startScan([]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Scan for devices'),
        ),
        body: StreamBuilder(
          stream: scanner.state,
          initialData: const BleScannerState(
            discoveredDevices: [],
            scanIsInProgress: false
          ),
          builder: (context, snapshot) {
            if(snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.discoveredDevices.length,
                itemBuilder: (context, index) {
                  dynamic device = snapshot.data!.discoveredDevices[index];
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
              );
            }
            else if(snapshot.hasError) {
              return const Text("Oops!");
            }
            else if(!snapshot.hasData) {
              return const Text("No Devices yet");
            }
            else {
              return Container();
            }
            // if(snapshot.data!.scanIsInProgress) {
            //   return const LinearProgressIndicator();
            // }
            // else if(snapshot.hasData) {
            //   snapshot.data!.discoveredDevices.map((device) {
            //     return Container();
            //   });
            // }
            // else if(snapshot.hasError) {
            //   return Container();
            // }
            // else {
            //   return Container();
            // }
            // return Container();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _startScanning,
          child: const Icon(Icons.abc),
        ), 
      );
}
