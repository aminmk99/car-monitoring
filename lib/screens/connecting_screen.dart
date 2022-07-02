import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:geolocator/geolocator.dart';

// ignore: must_be_immutable
class ConnectingScreen extends StatefulWidget {
  ConnectingScreen({
    Key? key,
    required this.device,
    required this.char,
    required this.characteristic,
    required this.myService,
  }) : super(key: key);
  var device;

  var char;

  var characteristic;

  var myService;

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  var temp;

  bool isTapped = false;

  bool isConnected = true;

  List<double>? _accelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  var acc;
  var gyro;
  var magnet;

  Position? position;
  late String pos;
  late String y = '?';
  late String x = '?';

  @override
  void initState() {
    super.initState();
    _streamSubscriptions.add(
      accelerometerEvents.listen(
        (AccelerometerEvent event) {
          setState(() {
            _accelerometerValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    _streamSubscriptions.add(
      gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    _streamSubscriptions.add(
      magnetometerEvents.listen(
        (MagnetometerEvent event) {
          setState(() {
            _magnetometerValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    loopFunc();
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accelerometer =
        _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final gyroscope =
        _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final magnetometer =
        _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.greenAccent,
        ),
        title: Text(
          'Embedded',
          style: TextStyle(
            color: Colors.greenAccent,
          ),
        ),
      ),
      body: bodyMaker(accelerometer, gyroscope, magnetometer),
    );
  }

  Widget bodyMaker(var accelerometer, var gyroscope, var magnetometer) {
    if (!isTapped) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.greenAccent,
        ),
      );
    } //
    else {
      setState(() {
        acc = accelerometer;
        gyro = gyroscope;
        magnet = magnetometer;
      });
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(200, 200),
                  shape: const CircleBorder(),
                  primary: Colors.greenAccent,
                ),
                onPressed: () => stopContinueFunc(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.thermostat,
                      size: 80,
                      color: Colors.black,
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Text(
                      "${temp} C°",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text('Accelerometer: $accelerometer'),
              SizedBox(height: 10),
              Text('Gyroscope: $gyroscope'),
              SizedBox(height: 10),
              Text('Magnetometer: $magnetometer'),
              SizedBox(height: 20),
              Row(
                children: [
                  Text('Longitude: $y'),
                  SizedBox(width: 20),
                  Text('Latitude: $x'),
                ],
              ),
            ],
          ),
        ],
      );
    }
  } //making body of scaffold

  loopFunc() async {
    setState(() {
      isTapped = true;
    });
    var service = widget.myService;
    print('-------------Entered loopFunc-------------');
    String decodedData = '';
    // Reads all characteristics
    var characteristics = service.characteristics;

    while (isConnected) {
      print('Entered loopFunc.while');
      for (BluetoothCharacteristic c in characteristics) {
        print('Entered loopFunc.for');
        List<int> value = await c.read();
        decodedData = utf8.decode(value);
        print(decodedData);
        setState(() {
          temp = decodedData;
        });
      }
      await getCurrentLocation();
      connect();
    }
  }

  Future<MqttServerClient> connect() async {
    MqttServerClient client =
        MqttServerClient.withPort('45.149.77.235', 'flutter_client', 1883);
    client.logging(on: true);
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    // client.onUnsubscribed = onUnsubscribed as UnsubscribeCallback;
    client.onSubscribed = onSubscribed;
    client.onSubscribeFail = onSubscribeFail;
    client.pongCallback = pong;

    final connMessage = MqttConnectMessage()
        .authenticateAs('97522256', 'eFdpPb3p')
        // ignore: deprecated_member_use
        .keepAliveFor(60)
        .withWillTopic('willtopic')
        .withWillMessage('Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMessage;
    try {
      await client.connect();
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);

      print('Received message:$payload from topic: ${c[0].topic}>');
    });

    client.subscribe("97522256/amin", MqttQos.atLeastOnce);

    const pubTopic = '97522256/amin';
    final builder = MqttClientPayloadBuilder();
    builder.addString('Temperature $temp, Accelerometer: $acc, Gyroscope: $gyro, Magnetometer: $magnet, Longitude: $y, Latitude: $x');
    client.publishMessage(pubTopic, MqttQos.atLeastOnce, builder.payload!);

    return client;
  }

  // connection succeeded
  void onConnected() {
    print('Connected');
  }

// unconnected
  void onDisconnected() {
    print('Disconnected');
  }

// subscribe to topic succeeded
  void onSubscribed(String topic) {
    print('Subscribed topic: $topic');
  }

// subscribe to topic failed
  void onSubscribeFail(String topic) {
    print('Failed to subscribe $topic');
  }

// unsubscribe succeeded
  void onUnsubscribed(String topic) {
    print('Unsubscribed topic: $topic');
  }

// PING response received
  void pong() {
    print('Ping response client callback invoked');
  }

  stopContinueFunc() {
    setState(() {
      if (isConnected) {
        isConnected = false;
      } //
      else {
        isConnected = true;
        loopFunc();
      }
    });
  }

  getCurrentLocation() async{
    position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      y = position!.longitude.toStringAsFixed(5);
      x = position!.latitude.toStringAsFixed(5);
    });
  }
}
