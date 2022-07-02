import 'package:car_monitor/screens/connecting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String deviceName = '';

  FlutterBlue flutterBlue = FlutterBlue.instance;

  var device;

  var myService;

  var char;

  bool isConnected = false;

  bool isScanned = false;

  int counter = 0;

  var characteristic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search Screen',
          style: TextStyle(
            color: Colors.greenAccent,
          ),
        ),
      ),
      body: bodyMaker(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          scan();
        },
        child: Icon(Icons.search),
      ),
    );
  }

  Widget bodyMaker() {
    if (isScanned == false && counter == 0) {
      return Center(
        child: Text(
          "Please tap on the search button!",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
          ),
        ),
      );
    } //
    else if (isScanned == false && counter > 0) {
      return Center(
        child: Text(
          "Embeded was not found!",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
          ),
        ),
      );
    } //
    else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              deviceName + " " + " was found",
              style: TextStyle(
                fontSize: 17,
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.greenAccent,
                ),
                onPressed: () async {
                  connect(device);
                },
                child: Text(
                  'connect',
                  style: TextStyle(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  } //body maker

  scan() async {
    var id;
    deviceName = '';
    // Start scanning
    flutterBlue.startScan(timeout: Duration(seconds: 4));

    // Listen to scan results
    var subscription = flutterBlue.scanResults.listen(
      (results) {
        // do something with scan results
        for (ScanResult r in results) {
          print('${r.device.name} found! rssi: ${r.rssi}');
          id = r.device.id.toString();
          if (r.device.name == "Embeded" && id == 'EC:94:CB:70:12:1A') {
            setState(
              () {
                isScanned = true;
                device = r.device;
                deviceName = r.device.name;
              },
            );
            break;
          } else {
            setState(() {
              counter += 1;
            });
          }
        }
      },
    );

    // Stop scanning
    await flutterBlue.stopScan();
  }

  connect(device) async {
    if (isConnected == false) {
      // Connect to the device
      await device.connect();
      isConnected = true;
      print('connect to embeded');
      readServices();
    } //
    else if (isConnected) {
      // Disconnect from device
      device.disconnect();
      setState(() {
        isConnected = false;
      });
      connect(device);
    }
  }

  readServices() async {
    List<BluetoothService> services = await device.discoverServices();
    services.forEach(
      (service) {
        print('----------------------------');
        myService = service;
        print(service);
      },
    );
    readCharacteristic();
  }

  readCharacteristic() async {
    // Reads all characteristics
    var characteristics = myService.characteristics;
    for (BluetoothCharacteristic c in characteristics) {
      List<int> value = await c.read();
      await c.write([0x12, 0x34]);
      print('**********************************');
      char = value;
      characteristic = c;

      print(value);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: ((context) {
          return ConnectingScreen(
            device: device,
            char: char,
            characteristic: characteristic,
            myService: myService,
          );
        }),
      ),
    );
  }
}
