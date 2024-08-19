import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:bluetest/ble/ble_device_interactor.dart';
import 'package:bluetest/main.dart';
import 'package:bluetest/ui/device_detail/characteristic_interaction_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:intl/intl.dart';

class DeviceInfo extends StatefulWidget {

  final DiscoveredDevice device;
  const DeviceInfo({required this.device, super.key});

  @override
  State<StatefulWidget> createState() => _DeviceInfoState();
}

class _DeviceInfoState extends State<DeviceInfo> {

  int _rssi = 0;
  bool isNotifiable = false;
  bool deviceConnected = false;
  late List<Service> discoveredServices;

  DeviceConnectionState? connectionState;
  late BleDeviceInteractor serviceDiscoverer;
  
  StreamSubscription<ConnectionStateUpdate>? _connection;

  final SERVICE_ID = "0000fff0-0000-1000-8000-00805f9b34fb";
  final BLE_TO_MSA_CHARACTER_ID = "0000ff0b-0000-1000-8000-00805f9b34fb";
  final MSA_TO_BLE_CHARACTER_ID = "0000ff0a-0000-1000-8000-00805f9b34fb";
  
  String output = "";
  Characteristic? bleToMsaCharacteristic;
  Characteristic? msaToBleCharacteristic;

  Timer? timer;
  int recordNumber = 0;
  bool isFirstPacket = false;

  @override
  void initState() {
    discoveredServices = [];
    serviceDiscoverer = BleDeviceInteractor(
      bleDiscoverServices: (deviceId) async {
        await ble.discoverAllServices(deviceId);
        return ble.getDiscoveredServices(deviceId);
      },
      logMessage: bleLogger.addToLog,
      readRssi: ble.readRssi,
    );


    //
    super.initState();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }

  Future<void> discoverServices() async {
    final result = await serviceDiscoverer.discoverServices(widget.device.id);
    for (var element in result) {
      if(element.id.toString() == SERVICE_ID) {
        getCharacteristics(element);
      }
    }

    setState(() {
      discoveredServices = result;
    });
  }

  getCharacteristics(Service service) {
    for (var element in service.characteristics) {
      if(element.id.toString() == BLE_TO_MSA_CHARACTER_ID) {
        setState(() {
          bleToMsaCharacteristic = element;
        });
        syncDate(bleToMsaCharacteristic!);
      }

      if(element.id.toString() == MSA_TO_BLE_CHARACTER_ID) {
        setState(() {
          msaToBleCharacteristic = element;
        });
        subToCharacteristic(msaToBleCharacteristic!);
      }
    }
  }

  Future<void> subToCharacteristic(Characteristic characteristic) async {

    final char = QualifiedCharacteristic(serviceId: Uuid.parse(SERVICE_ID), characteristicId: characteristic.id, deviceId: widget.device.id);
    ble.subscribeToCharacteristic(char).listen((event) {

      int instructionType = event[0];
      if(instructionType == 170) {

        // Get status
        int status = event[1];
        if(status == 5) { // start polling
          startPolling();
        }

        if(status == 6) { // Stop polling
          timer?.cancel();

          // Ask for number of records
          writeData(bleToMsaCharacteristic!, [0x55, 01]); 
        }

        if(status == 1) { // Record number is back
          setState(() {
            isFirstPacket = true;
          });
          recordNumber = event[event.length - 2];
          writeData(bleToMsaCharacteristic!, [0x55, 02, 01, 00]);
        }

        if(status == 3) {
          print("Record deleted succesfully");
        }
      }

      if(instructionType == 221) {
        print("$event");
        if(isFirstPacket) {
           setState(() {
            isFirstPacket = false;
          });
          writeData(bleToMsaCharacteristic!, [0x55, 02, recordNumber, 00]); 
        }
        else { // Delete historical records 
          writeData(bleToMsaCharacteristic!, [0x55, 03]); 
        }
      }
    });
  }

  Future<void> writeData(Characteristic characteristic, List<int> data) async {
    final char = QualifiedCharacteristic(serviceId: Uuid.parse(SERVICE_ID), characteristicId: characteristic.id, deviceId: widget.device.id);
    await ble.writeCharacteristicWithResponse(char, value: data);
  }

  Future<void> syncDate(Characteristic characteristic) async {
    var dateUtc = DateTime.now();
    var formatter = DateFormat("yyyyMMddHHss");
    List<int> dateBytes = [0xDD];
    dateBytes.addAll(utf8.encode(formatter.format(dateUtc)));
    writeData(characteristic, dateBytes);
  }

  startPolling() {
    timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) async {
        await writeData(bleToMsaCharacteristic!, [0x55, 06]);
      },
    );
  }

  Future<void> startReading() async {
    subToCharacteristic(msaToBleCharacteristic!);
  }

  Future<void> readRssi() async {
    final rssi = await serviceDiscoverer.readRssi(widget.device.id);
    setState(() {
      _rssi = rssi;
    });
  }

  connect() {
    _connection = ble.connectToDevice(
      id: widget.device.id,
      connectionTimeout: const Duration(seconds: 2),).listen((state) {
      setState(() {
        connectionState = state.connectionState;
        deviceConnected =  state.connectionState == DeviceConnectionState.connected;
        if(deviceConnected) {
          discoverServices();
        }
      });
    }, onError: (Object error) {
      // Handle a possible error
      // print(error);
    });
  }

  disconnect() {
    _connection?.cancel();
    connectionState = null;
    deviceConnected = false;
    setState(() {});
    // connector.disconnect(widget.device.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
        children: [
          Text("Name: ${widget.device.name}"),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8.0, bottom: 16.0, start: 16.0),
            child: Text(
              "ID: ${widget.device.id}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16.0),
            child: Text(
              "Connectable: ${widget.device.connectable}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16.0),
            child: Text(
              "Connection: $connectionState",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16.0),
            child: Text(
              "Rssi: $_rssi dB",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              children: <Widget>[
                ElevatedButton(
                  onPressed: !deviceConnected ? connect : null,
                  child: const Text("Connect"),
                ),
                ElevatedButton(
                  onPressed: deviceConnected ? disconnect : null,
                  child: const Text("Disconnect"),
                ),
                ElevatedButton(
                  onPressed: deviceConnected ? discoverServices : null,
                  child: const Text("Discover Services"),
                ),
                ElevatedButton(
                  onPressed: deviceConnected
                      ? readRssi
                      : null,
                  child: const Text("Get RSSI"),
                ),
              ],
            ),
          ),

          Text("Notifiable: $isNotifiable"),
          const SizedBox(height: 10),
          Text("Output: $output"),

          if (deviceConnected)
            _ServiceDiscoveryList(
              deviceId: widget.device.id,
              discoveredServices: discoveredServices,
          ),
        ],
      ),
    )
    );
  }
}

class _ServiceDiscoveryList extends StatefulWidget {
  const _ServiceDiscoveryList({
    required this.deviceId,
    required this.discoveredServices,
    Key? key,
  }) : super(key: key);

  final String deviceId;
  final List<Service> discoveredServices;

  @override
  _ServiceDiscoveryListState createState() => _ServiceDiscoveryListState();
}

class _ServiceDiscoveryListState extends State<_ServiceDiscoveryList> {
  late final List<dynamic> _expandedItems;

  @override
  void initState() {
    _expandedItems = [];

    // for (var element in widget.discoveredServices) {
    //   element.characteristics.map((e) => {
    //     if (e.isWritableWithResponse) {

    //     }
    //   });
    // }

    //
    super.initState();
  }

  String _characteristicSummary(Characteristic c) {
    final props = <String>[];
    if (c.isReadable) {
      props.add("read");
    }
    if (c.isWritableWithoutResponse) {
      props.add("write without response");
    }
    if (c.isWritableWithResponse) {
      props.add("write with response");
    }
    if (c.isNotifiable) {
      props.add("notify");
    }
    if (c.isIndicatable) {
      props.add("indicate");
    }

    return props.join("\n");
  }

  Widget _characteristicTile(Characteristic characteristic) => ListTile(
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => CharacteristicInteractionDialog(characteristic: characteristic),
    ),
    title: Text(
      '${characteristic.id}\n(${_characteristicSummary(characteristic)})',
      style: const TextStyle(
        fontSize: 14,
      ),
    ),
  );

  List<ExpansionPanel> buildPanels() {
    final panels = <ExpansionPanel>[];

    widget.discoveredServices.asMap().forEach(
          (index, service) => panels.add(
            ExpansionPanel(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 16.0),
                    child: Text(
                      'Characteristics',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: service.characteristics.map(_characteristicTile).toList(),
                  ),
                ],
              ),
              headerBuilder: (context, isExpanded) => ListTile(
                title: Text(
                  '${service.id}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              isExpanded: _expandedItems.contains(index),
            ),
          ),
        );

    return panels;
  }

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsetsDirectional.only(
        top: 20.0,
        start: 20.0,
        end: 20.0,
      ),
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            if (isExpanded) {
              _expandedItems.add(index);
            } else {
              _expandedItems.remove(index);
            }
          });
        },
        
        children: buildPanels(),
    ),
  );
}
