import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'Widget_Function.dart';
import 'ble_device_connector.dart';
import 'ble_device_interactor.dart';
import 'ble_scanner.dart';
import 'ble_status_monitor.dart';
import 'package:geolocator/geolocator.dart';


List<int> _cmdToBLE(int op,int op1,List<int> buf){
  List<int> _CmdBuff= [0x23,0,0x30+op,0x30+op1]+buf;
    // while(_CmdBuff.length<31){_CmdBuff.add(0);}
    int sumcks = 0;
  _CmdBuff.add(sumcks);
  _CmdBuff.add(0x0d);
  _CmdBuff.add(0x0a);
  _CmdBuff[1]=_CmdBuff.length;
    for(int i=0;i<_CmdBuff.length-2;i++){sumcks = sumcks+_CmdBuff[i];}
  _CmdBuff[ _CmdBuff.length-3]=sumcks;

    print("_CmdBuff ${_CmdBuff.toList().toString()}");
  return _CmdBuff;
}


Future<void> checkLocationPermission() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Check if location services are enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled
    return;
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are permanently denied
    return;
  }

  // Permissions granted – get location
  Position position = await Geolocator.getCurrentPosition();
  print(position);
}

Future<void> requestNearbyPermissions() async {
  if (await Permission.bluetoothScan.isDenied) {
    await Permission.bluetoothScan.request();
  }

  if (await Permission.bluetoothConnect.isDenied) {
    await Permission.bluetoothConnect.request();
  }

  if (await Permission.nearbyWifiDevices.isDenied) {
    await Permission.nearbyWifiDevices.request();
  }
  if (await Permission.location.isDenied) {
    checkLocationPermission();
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  requestNearbyPermissions();
  final ble = FlutterReactiveBle();
  final scanner = BleScanner(ble: ble);
  final _connector = BleDeviceConnector(ble: ble);
  final monitor = BleStatusMonitor(ble);

  final _serviceDiscoverer = BleDeviceInteractor(
    bleDiscoverServices: ble.discoverServices,
    readCharacteristic: ble.readCharacteristic,
    writeWithResponse: ble.writeCharacteristicWithResponse,
    writeWithOutResponse: ble.writeCharacteristicWithoutResponse,
    subscribeToCharacteristic: ble.subscribeToCharacteristic,
  );
  runApp(MultiProvider(providers: [
    Provider.value(value: scanner),
    Provider.value(value: _serviceDiscoverer),
    Provider.value(value: _connector),
    StreamProvider<ConnectionStateUpdate>(
      create: (_) => _connector.state,
      initialData: const ConnectionStateUpdate(
        deviceId: 'Unknown device',
        connectionState: DeviceConnectionState.disconnected,
        failure: null,
      ),
    ),
    StreamProvider<BleScannerState?>(
      create: (_) => scanner.state,
      initialData: const BleScannerState(
        discoveredDevices: [],
        scanIsInProgress: false,
        scanIsPause: 0,
      ),
    ),
    StreamProvider<BleStatus?>(
      create: (_) => monitor.state,
      initialData: BleStatus.unknown,
    ),
  ], child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  late BleDeviceConnector mBleDeviceConnector;
  late BleDeviceInteractor mBleDeviceInteractor;
  late QualifiedCharacteristic writecharacteristic, readcharacteristic;
  // late ConnectionStateUpdate mConnectionStateUpdate;
  late BleScanner mBleScanner;
  StreamSubscription<List<int>>? subscribeStream;

  late TextEditingController _controller;


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    mBleDeviceConnector = Provider.of<BleDeviceConnector>(context, listen: false);
    mBleDeviceInteractor = Provider.of<BleDeviceInteractor>(context, listen: false);
    // mConnectionStateUpdate = Provider.of<ConnectionStateUpdate>(context, listen: false);
    mBleScanner = Provider.of<BleScanner>(context, listen: false);

    _controller = TextEditingController();

    // WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
    //   // if (widget.deviceConnected && !oldwidget.deviceConnected) {
    //   subscribeCharacteristic();
    //
    //   // } else {}
    // });
  }
  // bool get deviceConnected => mConnState.connectionState == DeviceConnectionState.connected;
String checkinterval(interval){
  switch(interval){
    case 0x0:return "interval: 15 sec";break;
    case 0x1:return "interval: 30 sec";break;
    case 0x2:return "interval: 10 min";break;
    case 0x3:return "interval: 1 hour";break;
    default:return "NaN";
  }
}
  @override
  void didUpdateWidget(MyHomePage oldwidget) {
    super.didUpdateWidget(oldwidget);
    //mConnectionStateUpdate.connectionState == DeviceConnectionState.connected
    //mConnState.connectionState == DeviceConnectionState.connected
    print("didUpdateWidget ");
    writecharacteristic = mBleDeviceConnector.writecharacteristic;
    readcharacteristic = mBleDeviceConnector.readcharacteristic;

  }
  Timer rssilooptimer = Timer.periodic(const Duration(seconds: 1), (timer) {

  });
      Future<void> subscribeCharacteristic() async {
    subscribeStream = mBleDeviceConnector.readBuffStream.listen((event) {
      // subscribeStream =
      print("meter res : ${event.toString()}");
      String res = "";
      String opCode = "${event[2]}-${event[3]}";
       try {
         switch (opCode) {
           case "1-0":
             res = "mode: ${event[4] == 0x31 ? "Wifi" : event[4] == 0x32 ? "5G" : "Wifi"}\n"
                 "${checkinterval(0)}\n"
                 "${String.fromCharCodes(event.sublist(7, 7 + event[6]))}\n"
                 "${String.fromCharCodes(event.sublist(7 + event[6] + 1, 7 + event[6] + 1 + event[7 + event[6]]))}\n"
                 "${String.fromCharCodes(event.sublist(7 + event[6] + 1 + event[7 + event[6]], event.length - 2))}\n"
                 "";
             break;
           case "1-1":
             res = "mode: ${event[4] == 0x31 ? "Wifi" : event[4] == 0x32 ? "5G" : "Wifi"}"; //String.fromCharCodes(event.sublist(4,event.length-3));
             break;
           case "1-2":
             switch (event[4]) {
               case 0:
                 res = "OK";
                 break;
               case 1:
                 res = "High-side pressure is working";
                 break;
               case 2:
                 res = "Low-side pressure is working";
                 break;
               case 3:
                 res = "No High-side pressure";
                 break;
               case 4:
                 res = "No Low-side pressure";
                 break;
               case 5:
                 res = "No Supply Pre Coil sensor";
                 break;
               case 6:
                 res = "No Supply Post Coil sensor";
                 break;
               case 7:
                 res = "No Supply Air Velocity sensor";
                 break;
               case 8:
                 res = "No Return Pre Filter sensor";
                 break;
               case 9:
                 res = "No Return Post Filter sensor";
                 break;
               default:
                 res = "NaN";
             }
             break;
           case "1-3":
             res = checkinterval(event[4]);
             break;
           case "1-4": //wifi setting

             break;
           case "1-5":
             res = "timestamp: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
             break;
           case "1-6": //return to the default settings
             res = " ${event[4]}";
             break;
           case "1-7": //return to the default settings
             res = " ${event[4]}";
             break;
           case "1-8": //return to the default settings
             res = " [${event[4]},${event[5]},${event[6]},${event[7]},${event[8]}]";
             break;
           case "2-0":
             res =
             "fw: ${event[4]}.${event[5]}.${event[6]}\n"
                 "cal: ${event[7]}${event[8]}${event[9]}${event[10]}\n"
                 "commission: ${event[11]}${event[12]}${event[13]}${event[14]}\n"
                 "Wifi Mac: ${hex.encode(event.sublist(15,21))}\n"
                 "BLE Mac: ${hex.encode(event.sublist(21,27))}\n"
                 "Cellular IMEI: ${hex.encode(event.sublist(27,35))}\n"
                 "Lora Eui: ${hex.encode(event.sublist(35,43))}\n"
                 "eSim:\n"
                 "Secret key: ${String.fromCharCodes(event.sublist(43, 59))}\n"
                 "ICC ID: ${String.fromCharCodes(event.sublist(59, 69))}\n"
                 "UPC: ${String.fromCharCodes(event.sublist(69, 91))}\n"
                 "IMSI: ${String.fromCharCodes(event.sublist(91, 99))}\n"
                 "UPC: ${String.fromCharCodes(event.sublist(69, 91))}\n"
                 "MCU Speed: ${event[91]}\n"
                 "Flash Memory: ${event[92] << 24 | event[93] << 16 | event[94] << 8 | event[95]}\n"
             ;
             break;
           case "2-1": //return to the default settings
             res = "calibration: ${byteToHexString(event.sublist(4, event.length - 3))}";
             break;
           case "2-2": //return to the default settings
             res = "commisson: ${byteToHexString(event.sublist(4, event.length - 3))}";
             break;
           case "3-0": //return to the default settings
             res = "forward: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
             break;
           case "3-1": //return to the default settings
             res = "getdata: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
             break;
           case "4-0":
           case "5-0":
             var eplen = event[4];
             var tplen = event[event[4] + 5];
             res = "endpoint: ${String.fromCharCodes(event.sublist(5, 5 + eplen))}\n"
                 "topic: ${String.fromCharCodes(event.sublist(5 + eplen + 1, event[4] + 5 + 1 + tplen))}\n"
                 "s/n:${String.fromCharCodes(event.sublist(event[4] + 5 + 1 + tplen, event[4] + 5 + 1 + tplen + 4))}\n"
                 "manufacturing date: ${String.fromCharCodes(event.sublist(event[4] + 5 + 1 + tplen + 4, event[4] + 5 + 1 + tplen + 4 + 4))}"
             ;
             break;
           case "5-1":
             res = "endpoint: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
             break;
           case "5-2":
             res = "topic: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
             break;
           case "5-3":
             res = "SN: ${byteToHexString(event.sublist(4, event.length - 3))}";
             break;
           case "5-4":
             res = "topic: ${byteToHexString(event.sublist(4, event.length - 3))}";
             break;
           default:
             var nowtimt = DateTime.now();
             res = "${nowtimt.hour}:${nowtimt.minute}:${nowtimt.second}-other: ${ String.fromCharCodes(event.sublist(4, event.length - 3))}";

             break;
         }
       }catch(e){
         res = e.toString();
       }
      readBuffer.insert(0,res);
      if(readBuffer.length>10000)
        {
          readBuffer.removeAt(readBuffer.length-1);
        }
      setState(() {

      });
    });
  }




  @override
  void dispose() {
    super.dispose();
    print("Probe dispose");
    _controller.dispose();
    wifissidcontrol.dispose();
    wifipasscontrol.dispose();
    awsendpointcontrol.dispose();
    setsncontrol.dispose();
    forwarduplinkcontrol.dispose();
    if (subscribeStream != null) {
      if (!subscribeStream!.isPaused) {
        subscribeStream?.cancel();
      }
    }
    if(rssilooptimer.isActive){
      rssilooptimer.cancel();
    }
  }

  int filteridx = 0;
  List<String> _markupFilter = [];
  BleStatus mBLEStat = BleStatus.unknown;
  Map<String, DiscoveredDevice> mblelist = {};
  Map<String, CHY_Packet> mbeaconlist = {};
  List<String> readBuffer = [];

  final TextEditingController wifissidcontrol     = TextEditingController();
  final TextEditingController wifipasscontrol     = TextEditingController();
  final TextEditingController timestampaligncontrol     = TextEditingController();
  final TextEditingController aligntimebuff = TextEditingController();
  final List<int> alignhextimebuff     = [0,0,0,0,0,0];
  final TextEditingController awsendpointcontrol  = TextEditingController();
  final TextEditingController setsncontrol        = TextEditingController();
  final TextEditingController forwarduplinkcontrol = TextEditingController();
  final TextEditingController commissiondatecontrol = TextEditingController();
  final TextEditingController calibrationdatecontrol = TextEditingController();
  final TextEditingController iotendpointcontrol = TextEditingController();
  final TextEditingController iotmqtttopiccontrol = TextEditingController();
  final TextEditingController manufactorydatecontrol = TextEditingController();


  int sensordata1_8idx= 2,metadata1_8idx=2,status1_8idx=2,hwperformance1_8idx=2,hwerror1_8idx=2;
  int sensordata1_3idx= 1,metadata1_3idx=1,status1_3idx=1,hwperformance1_3idx=1,hwerror1_3idx=1;
  String connectid = "";
  int rssiVal = 0;

  List<int> _calibrationDateBuf = [0,0,0,0],_commissionDateBuf = [0,0,0,0],
      setSNBuf=[0,0,0,0],setManufacturingBuf=[0,0,0,0];
var stat = DeviceConnectionState.disconnected;
  @override
  Widget build(BuildContext context) => Consumer3<ConnectionStateUpdate,BleScannerState,BleStatus>(
      builder: (_, mConnectionStateUpdate,bleScannerState,status, __) {
        if( status == BleStatus.ready){
          //  print("bleScannerState.scanIsPause {${mblescanner.state}");
          if(bleScannerState.scanIsPause>1){///應該只會在藍芽關閉->啟動時才會遇到,app啟動時應該要會自動搜尋
            print("log scan automacally.");
            mBleScanner.startScan([]);

          }
        }
        if(mConnectionStateUpdate.connectionState == DeviceConnectionState.connected&&stat!=DeviceConnectionState.connected){
          writecharacteristic = mBleDeviceConnector.writecharacteristic;
          readcharacteristic = mBleDeviceConnector.readcharacteristic;
          readBuffer.clear();
          subscribeCharacteristic();
          rssilooptimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
            mBleDeviceConnector.getRssi(connectid).then((onValue){
              rssiVal = onValue;
              setState(() {

              });
            });
          });
        }else if(mConnectionStateUpdate.connectionState == DeviceConnectionState.disconnected&&stat!=DeviceConnectionState.disconnected) {

          if(subscribeStream!=null) {
            subscribeStream!.cancel();
            subscribeStream = null;
          }

          if(rssilooptimer.isActive) {
            rssilooptimer.cancel();
          }
        }

      stat = mConnectionStateUpdate.connectionState;

        for (var device in bleScannerState.discoveredDevices) {

          if (device.manufacturerData.length > 26) {
            if (device.manufacturerData[3] == 84 && device.manufacturerData[4] == 77) {
              if (filteridx != 1) {
                var mmCHY_Packet = CHY_Packet.thermoOld(
                    DateTime.now().second,
                    ((device.manufacturerData[14] << 8 | device.manufacturerData[15]) / 10),
                    //double
                    ((device.manufacturerData[16] << 8 | device.manufacturerData[17]) / 10),
                    //double
                    device.manufacturerData[18],
                    device.manufacturerData[19],
                    device.manufacturerData[20],
                    device.manufacturerData[21],
                    (device.manufacturerData[11] << 8 | device.manufacturerData[1]),
                    device.manufacturerData[12],
                    device.manufacturerData[13],
                    device.manufacturerData[22],
                    device.manufacturerData[23],
                    device.manufacturerData[24]);
                mmCHY_Packet.sn = "${String.fromCharCode(device.manufacturerData[0])}"
                    "${String.fromCharCode(device.manufacturerData[1])}"
                    "${String.fromCharCode(device.manufacturerData[2])}"
                    "${device.manufacturerData[5].toRadixString(16).padLeft(2, '0')}"
                    "${device.manufacturerData[6].toRadixString(16).padLeft(2, '0')}"
                    "${device.manufacturerData[7].toRadixString(16).padLeft(2, '0')}"
                    "${device.manufacturerData[8].toRadixString(16).padLeft(2, '0')}"
                    "${String.fromCharCode(device.manufacturerData[3])}"
                    "${String.fromCharCode(device.manufacturerData[4])}";
                if (filteridx == 3) {
                  if (_markupFilter.contains(mmCHY_Packet.id)) {
                    mmCHY_Packet.Batt = device.manufacturerData[9];
                    mmCHY_Packet.id = device.id;
                    mbeaconlist[device.id] = mmCHY_Packet;
                    mblelist.remove(device.id);
                  }
                } else {
                  mmCHY_Packet.Batt = device.manufacturerData[9];
                  mmCHY_Packet.id = device.id;
                  mbeaconlist[device.id] = mmCHY_Packet;
                  mblelist.remove(device.id);
                }

                /// Beacon & BLE 在收到該筆裝置資料後刪除對方的buffer,防止meter切換時殘留, null時刪除還是null
              }
            }
          } else if (device.manufacturerData.isEmpty) {
            if (filteridx != 2) {
              if (filteridx == 3) {
                if (_markupFilter.contains(device.id)) {
                  mblelist[device.id] = device;
                  mbeaconlist.remove(device.id);
                }
              } else {
                mblelist[device.id] = device;
                mbeaconlist.remove(device.id);
              }

              /// Beacon & BLE 在收到該筆裝置資料後刪除對方的buffer,防止meter切換時殘留, null時刪除還是null
            }
          }
        }


        return Scaffold(
          appBar: AppBar(
            //title: Text("${mConnectionStateUpdate.connectionState == DeviceConnectionState.connected}"),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              mConnectionStateUpdate.connectionState == DeviceConnectionState.connected
                  ? TextButton(
                      onPressed: () {
                        mBleDeviceConnector.disconnect(connectid);
                      },
                      child: const Text("disconnect"))
                  : TextButton(
                      onPressed: () {
                        mBleScanner.startScan([]);
                      },
                      child: const Text("scan"))
            ],
          ),
          body: Center(
            child: mConnectionStateUpdate.connectionState == DeviceConnectionState.connected
                ? Column(children: [
              Expanded(child: SingleChildScrollView(child:
                Column(children: [



                  ElevatedButton(onPressed: (){
                    var inputBuff = [];

                    // inputBuff.addAll([utf8.encode(_controller.text)]);
                    // ///寫入緩衝區
                    // print(inputBuff);
                    // if(inputBuff.length>20) {
                    //   mBleDeviceInteractor.writeCharacterisiticWithResponse(mBleDeviceConnector.writecharacteristic, []);
                    // }
                    var event=List.generate(55, (index)=>index);
                    event[6] = 17;
                    event[24] = 8;
                   var res = "mode: ${event[4] == 0x31 ? "Wifi" : event[4] == 0x32 ? "5G" : "Wifi"}\n"
                        "${checkinterval(0x30)}\n"
                        "${(event.sublist(7,7+event[6])).join()}\n"
                        "${event.sublist(7+event[6]+1,7+event[6]+1+event[7+event[6]]).join()}\n"
                        "${event.sublist(7+event[6]+1+event[7+event[6]],event.length-2).join()}\n"
                        "";
//.toRadixString(16)
                    var sss=[0x12,0x34,0x56,0x78];
                    String dfdd= "";
                    sss.forEach((e){
                      dfdd+= e.toRadixString(16);
                    });
                    print("send${dfdd}");
                    // print("send${mBleDeviceInteractor.writeCharacterisiticWithResponse(mBleDeviceConnector.writecharacteristic, [0x23,0x06,0x69,0x92,0x0D,0x0A])}");
                    setState(() {
                      // mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, [0x23,0x06,0x69,0x92,0x0D,0x0A]);

                    });
                    }, child: Text("0.0 test submit")),
                  Divider(),
                  Text("1.user info"),
                  Card(margin: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
                      child: Column(children: [
                      Row(children: [ ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 0, [0]));}), child: Text("1.0 get user setting"))]),
                        Text("backhual connection"),
                        SingleChildScrollView(
                      scrollDirection: Axis.horizontal,  // 指定為水平滾動

                      child: Row(children: [
                        ///get backhual connection
                        ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 1, [0x0]));}), child: Text("1.1 set Wifi")),
                        ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 1, [0x1]));}), child: Text("1.1 set LoRa")),
                        ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 1, [0x2]));}), child: Text("1.1 5G"))
                      ],)),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20),child: Divider()),
                    Row(children: [
                      ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 2, [0]));}), child: Text("1.2 sensor zeroing"))
                    ],),
                        Text("uplink interval"),
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,  // 指定為水平滾動
                            child:Row(children: [
                              Column(children: [ ElevatedButton(onPressed: (){

                                showuplinkintervalDialog(context: context, title: "sensor data").then((onValue){
                                  setState(() {
                                    sensordata1_3idx = onValue;
                                  });
                                });

                              }, child: Text("SensorData")),Text("${_useruplinkIntervalBuff[sensordata1_3idx]}")],),

                              Column(children: [ ElevatedButton(onPressed: (){

                                showuplinkintervalDialog(context: context, title: "metadata").then((onValue){
                                  setState(() {
                                    metadata1_3idx = onValue;
                                  });
                                });

                              }, child: Text("metaData")),Text("${_useruplinkIntervalBuff[metadata1_3idx]}")],),
                              Column(children: [ ElevatedButton(onPressed: (){

                                showuplinkintervalDialog(context: context, title: "Status").then((onValue){
                                  setState(() {
                                    status1_3idx = onValue;
                                  });
                                });

                              }, child: Text("Status")),Text("${_useruplinkIntervalBuff[status1_3idx]}")],),
                              Column(children: [ ElevatedButton(onPressed: (){

                                showuplinkintervalDialog(context: context, title: "HW Performance").then((onValue){
                                  setState(() {
                                    hwperformance1_3idx = onValue;
                                  });
                                });

                              }, child: Text("HW Performance")),Text("${_useruplinkIntervalBuff[hwperformance1_3idx]}")],),
                              Column(children: [ ElevatedButton(onPressed: (){

                                showuplinkintervalDialog(context: context, title: "HW Error").then((onValue){
                                  setState(() {
                                    hwerror1_3idx = onValue;
                                  });
                                });

                              }, child: Text("HW Error")),Text("${_useruplinkIntervalBuff[hwerror1_3idx]}")],),
                            ])
                        ),
                        ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3,[sensordata1_3idx,metadata1_3idx,status1_3idx,hwperformance1_3idx,hwerror1_3idx]));}), child: Text("1.3 submit")),
                    // SingleChildScrollView(
                    //     scrollDirection: Axis.horizontal,  // 指定為水平滾動
                    //     child: Row(
                    //
                    //       children: [
                    //    //     ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, []));}), child: Text("get uplink interval")),
                    //         ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, [0x0]));}), child: Text("1.3 15 sec")),
                    //         ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, [0x1]));}), child: Text("1.3 30 sec")),
                    //         ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, [0x2]));}), child: Text("1.3 10 min")),
                    //         ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, [0x3]));}), child: Text("1.3 1 h"))
                    //       ],)),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20),child: Divider()),
                    Row(children: [

                      Expanded(child:  TextField(
                        controller: wifissidcontrol,
                        decoration: const InputDecoration(
                          labelText: 'SSID',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          wifissidcontrol.text=text;
                          print('Text changed: $text');
                        },
                        onSubmitted: (text) {
                          print('Text submitted: $text');
                        },
                      ) ),
                      //   ElevatedButton(onPressed: (){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1,4, wifissidcontrol.text.codeUnits));}, child: Text("submit"))
                    ],),
                    Row(children: [

                      Expanded(child:  TextField(
                        controller: wifipasscontrol,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          wifipasscontrol.text=text;
                          print('Text changed: $text');
                        },
                        onSubmitted: (text) {
                          print('Text submitted: $text');
                        },
                      ) ),
                    ],),
                        ElevatedButton(onPressed: (){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 4, [wifissidcontrol.text.codeUnits.length]+wifissidcontrol.text.codeUnits+[wifipasscontrol.text.codeUnits.length]+wifipasscontrol.text.codeUnits));}, child: Text("1.4 submit")),

                        Padding(padding: EdgeInsets.symmetric(horizontal: 20),child: Divider()),

                        ElevatedButton(onPressed: ((){
                          DateTime nowT = DateTime.now().toUtc();

                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 5,
                              [nowT.year-2000,nowT.month,nowT.day,nowT.hour,nowT.minute,nowT.second]));
                        }), child: Text("1.5 align")),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20),child: Divider()),
                        Row(children: [
                          ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 6, [0]));}), child: Text("1.6 return to the default settings")),
                        ],),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20),child: Divider()),
                        Text("BLE Advertisement Duration"),
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,  // 指定為水平滾動
                            child: Row(

                              children: [
                                //     ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, []));}), child: Text("get uplink interval")),
                                ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 7, [0x0]));}), child: Text("1.7 3 min")),
                                ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 7, [0x1]));}), child: Text("1.7 5 min")),
                                ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 7, [0x2]));}), child: Text("1.7 7 min")),
                                ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 7, [0x3]));}), child: Text("1.7 10 min"))
                              ],)),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20),child: Divider()),
                        Text("BLE transmission interval"),

                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,  // 指定為水平滾動
                            child:Row(children: [
                             Column(children: [ ElevatedButton(onPressed: (){

                               showintervalDialog(context: context, title: "sensor data").then((onValue){
                                 setState(() {
                                   sensordata1_8idx = onValue;
                                 });
                               });

                             }, child: Text("SensorData")),Text("${_userIntervalBuff[sensordata1_8idx]}")],),

                              Column(children: [ ElevatedButton(onPressed: (){

                                showintervalDialog(context: context, title: "metadata").then((onValue){
                                  setState(() {
                                    metadata1_8idx = onValue;
                                  });
                                });

                              }, child: Text("metaData")),Text("${_userIntervalBuff[metadata1_8idx]}")],),
                              Column(children: [ ElevatedButton(onPressed: (){

                                showintervalDialog(context: context, title: "Status").then((onValue){
                                  setState(() {
                                    status1_8idx = onValue;
                                  });
                                });

                              }, child: Text("Status")),Text("${_userIntervalBuff[status1_8idx]}")],),
                              Column(children: [ ElevatedButton(onPressed: (){

                                showintervalDialog(context: context, title: "HW Performance").then((onValue){
                                  setState(() {
                                    hwperformance1_8idx = onValue;
                                  });
                                });

                              }, child: Text("HW Performance")),Text("${_userIntervalBuff[hwperformance1_8idx]}")],),
                              Column(children: [ ElevatedButton(onPressed: (){

                                showintervalDialog(context: context, title: "HW Error").then((onValue){
                                  setState(() {
                                    hwerror1_8idx = onValue;
                                  });
                                });

                              }, child: Text("HW Error")),Text("${_userIntervalBuff[hwerror1_8idx]}")],),
                        ])
                        ),
                        ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 8, [sensordata1_8idx,metadata1_8idx,status1_8idx,hwperformance1_8idx,hwerror1_8idx]));}), child: Text("1.8 submit")),

                      ],)),
                  Divider(),
                  Text("2.box info"),
                  Card(child: Column(children: [
                    Row(children: [
                      ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(2, 0, [0]));}), child: Text("2.0 get box info")),
                    ],),
                    Row(children: [
                    Expanded(child:  TextField(
                      keyboardType: TextInputType.number, // 呼出数字键盘
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // 只允许数字输入
                      ],
                      controller: calibrationdatecontrol,
                      decoration: const InputDecoration(
                        labelText: 'calibration date',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (text) {
                        if(text.length==8) {
                          _calibrationDateBuf[0]=int.parse(text.substring(0,2),radix: 16);
                          _calibrationDateBuf[1]=int.parse(text.substring(2,4),radix: 16);
                          _calibrationDateBuf[2]=int.parse(text.substring(4,6),radix: 16);
                          _calibrationDateBuf[3]=int.parse(text.substring(6,8),radix: 16);
                        }
                        print('Text changed: $_calibrationDateBuf');
                      },
                      onSubmitted: (text) {
                        print('Text submitted: $text');
                      },
                    ) ), ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(2, 1, _calibrationDateBuf));}), child: Text("2.1    cal    ")),
                  ],),
                    Row(children: [
                      Expanded(child:  TextField(
                        keyboardType: TextInputType.number, // 呼出数字键盘
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly, // 只允许数字输入
                        ],
                        controller: commissiondatecontrol,
                        decoration: const InputDecoration(
                          labelText: 'commission date',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          if(text.length==8) {
                            _commissionDateBuf[0]=int.parse(text.substring(0,2),radix: 16);
                            _commissionDateBuf[1]=int.parse(text.substring(2,4),radix: 16);
                            _commissionDateBuf[2]=int.parse(text.substring(4,6),radix: 16);
                            _commissionDateBuf[3]=int.parse(text.substring(6,8),radix: 16);
                          }
                          print('Text changed: $text');
                        },
                        onSubmitted: (text) {
                          print('Text submitted: $text');
                        },
                      ) ), ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(2, 2, _commissionDateBuf));}), child: Text("2.2 submit")),
                    ],),],),),

                  ///===3========================================
                  // Divider(),
                  // Text("message"),
                  // Card(child: Column(children: [ Row(children: [
                  //   ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(3, 0, []));}), child: Text("forward msg")),
                  // ],),
                  //   Row(children: [
                  //     ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(3, 1, []));}), child: Text("get data")),
                  //   ],),],)),
                  ///===4========================================
                  Divider(),
                  Text("4.reset"),
                  Row(children: [
                    ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(4, 0, [0]));}), child: Text("4.0 reboot")),
                  ],),
                  ///===5========================================
                  Divider(),
                  Text("developer"),
                  Card(child: Column(children: [
                    Row(children: [
                      ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 0, [0]));}), child: Text("5.0 get dev settings")),
                    ],),
                    Row(children: [
                      Expanded(child:  TextField(
                        controller: iotendpointcontrol,
                        decoration: const InputDecoration(
                          labelText: 'iot point',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          iotendpointcontrol.text=text;
                          print('Text changed: $text');
                        },
                        onSubmitted: (text) {
                          print('Text submitted: $text');
                        },
                      ) ), ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 1, iotendpointcontrol.text.codeUnits));}), child: Text("5.1 submit")),
                    ],),
                    Row(children: [
                      Expanded(child:  TextField(
                        controller: iotmqtttopiccontrol,
                        decoration: const InputDecoration(
                          labelText: 'iot topic',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          iotmqtttopiccontrol.text=text;
                          print('Text changed: $text');
                        },
                        onSubmitted: (text) {
                          print('Text submitted: $text');
                        },
                      ) ), ElevatedButton(onPressed: ((){
                        print("${iotmqtttopiccontrol.text.codeUnits}");
                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 2, iotmqtttopiccontrol.text.codeUnits));
                      }), child: Text("5.2 submit")),
                    ],),
                    Row(children: [
                      Expanded(child:  TextField(
                        controller: setsncontrol,
                        decoration: const InputDecoration(
                          labelText: 's/n',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          if(text.length==8) {
                            setSNBuf[0]=int.parse(text.substring(0,2),radix: 16);
                            setSNBuf[1]=int.parse(text.substring(2,4),radix: 16);
                            setSNBuf[2]=int.parse(text.substring(4,6),radix: 16);
                            setSNBuf[3]=int.parse(text.substring(6,8),radix: 16);
                          }

                          print('Text changed: $text');
                        },
                        onSubmitted: (text) {
                          print('Text submitted: $text');
                        },
                      ) ), ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 3, setSNBuf));}), child: Text("5.3 submit")),
                    ],),
                    Row(children: [
                      Expanded(child:  TextField(
                        controller: manufactorydatecontrol,
                        decoration: const InputDecoration(
                          labelText: 'manufacturing date',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          if(text.length==8) {
                            setManufacturingBuf[0]=int.parse(text.substring(0,2),radix: 16);
                            setManufacturingBuf[1]=int.parse(text.substring(2,4),radix: 16);
                            setManufacturingBuf[2]=int.parse(text.substring(4,6),radix: 16);
                            setManufacturingBuf[3]=int.parse(text.substring(6,8),radix: 16);
                          }

                          print('Text changed: $text');
                        },
                        onSubmitted: (text) {
                          print('Text submitted: $text');
                        },
                      ) ), ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 4, setManufacturingBuf));}), child: Text("5.4 submit")),
                    ],),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 20),child: Divider()),
                    Text("change role"),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,  // 指定為水平滾動
                        child: Row(

                          children: [
                            //     ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, []));}), child: Text("get uplink interval")),
                            ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 5, [0]));}), child: Text("5.5 indoor")),
                            ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 5, [1]));}), child: Text("5.5 outdoor")),
                            ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 5, [2]));}), child: Text("5.5 combined")),
                          ],)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 20),child: Divider()),
                    Text("dual uplink mode"),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,  // 指定為水平滾動
                        child: Row(
                          children: [
                            //     ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, []));}), child: Text("get uplink interval")),
                            ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 6, [0]));}), child: Text("5.6 off")),
                            ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(5, 6, [1]));}), child: Text("5.6 on")),
                          ],)),
                  ],),),

                  ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(6, 1, [0]));}), child: Text("6.1 undefined command")),
                  // Row(children: [
                  //   ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(6, 2, []));}), child: Text("get fw")),
                  // ],),


                ],))),
              Divider(),
              Text("received from BLE device, RSSI: $rssiVal "),

              SizedBox(height:200,
                  child:
        // ReorderableListView(onReorder: (int oldIndex, int newIndex) {
        //   setState(() {
        //     if (newIndex > oldIndex) newIndex -= 1;
        //     final item = readBuffer.removeAt(oldIndex);
        //     readBuffer.insert(newIndex, item);
        //   });
        // },
        // children: [...readBuffer.map((e) => Text(e))],)

              ListView(children: [
                ...readBuffer.map((e) => Text(e,softWrap: true))
              ]))

            ],)
                :

              ///目前 Beacon 每次只有一個,先加入list在做物件
              //  print("scan stat ${bleScannerState.scanIsPause}///${bleScannerState.scanIsInProgress} ");
            status != BleStatus.ready
                ? Center(
                child: status == BleStatus.locationServicesDisabled
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.blue,
                  ),
                  Flexible(child: Text("Please enable Locations on your device to continue."))
                ])
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                    Icons.bluetooth,
                    color: Colors.blue,
                  ),
                  Flexible(child: Text("Please enable Bluetooth on your device to get started."))
                ]))
                : ListView(children: [
              ///Beacon Widget first
              ...mbeaconlist.values
                  .map(
                    (device) => Card(
                    color: Color.fromRGBO(250, 250, 250, 1),
                    // margin: const EdgeInsets.fromLTRB(10, 5, 10, 0),
                    child: ListTile(
                      title: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(device.sn),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              IconButton(
                                color: Colors.grey,
                                icon: Icon(_markupFilter.contains(device.id) ? Icons.bookmark_added_rounded : Icons.bookmark_border),
                                onPressed: () {
                                  setState(() {
                                    if (!_markupFilter.contains(device.id)) {
                                      _markupFilter.add(device.id);
                                    } else {
                                      _markupFilter.remove(device.id);
                                    }
                                  });
                                },
                              ),
                              // IconButton(
                              //   color: Colors.grey,
                              //   icon: const Icon(Icons.keyboard_arrow_right),
                              //   onPressed: () {
                              //     showBottomView(context: context, title: device.id, builder: Chart_RealTimeMeasurement(device.id));
                              //   },
                              // )
                            ],
                          )),
                      subtitle: Column(children: [ListTile(title: Text(device.id),),
                      ],),
                      onTap: () async {
                      },
                    ) //SuccinctWidget(context,device)
                ),
              ),

              ///BLE widget under the Beacon widget
              ...mblelist.values
                  .map((device) => //${device.id}
              Card(
                  color: const Color.fromRGBO(250, 250, 250, 1),
                  child:
                  ListTile(
                    onTap: () {
                      mBleScanner.stopScan();
                      // widget.mBleScanner.stopScan();
                      connectid = device.id;
                      mBleDeviceConnector.connect(device.id);
                    },
                    contentPadding: const EdgeInsets.only(left: 15),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.id, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(device.name),
                        Text("RSSI: ${device.rssi}", style: const TextStyle(fontSize: 14)),
                      ],
                    ),

                    //leading: const Icon(Icons.add_circle_outline),
                    trailing: TextButton(
                      onPressed: () {

                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // IconButton(color: Colors.grey,onPressed: (){
                          //
                          // }, icon: Icon(Icons.upgrade)),
                          IconButton(
                            color: Colors.blue,
                            icon: Icon(_markupFilter.contains(device.id) ? Icons.bookmark_added_rounded : Icons.bookmark_border),
                            onPressed: () {
                              setState(() {
                                if (!_markupFilter.contains(device.id)) {
                                  _markupFilter.add(device.id);
                                } else {
                                  _markupFilter.remove(device.id);
                                }
                              });

                              print("dialog res : $_markupFilter");
                            },
                          ),
                          // IconButton(
                          //   color: Colors.grey,
                          //   icon: const Icon(Icons.keyboard_arrow_right),
                          //   onPressed: () {
                          //     Navigator.push(context, MaterialPageRoute(builder: (context) => ThermoBleDetailPage(snName: device.name)));
                          //     mblescanner.stopScan();
                          //     // widget.mBleScanner.stopScan();
                          //     connController.connect(device.id);
                          //   },
                          // )
                        ],
                      ),
                    ),

                  )


              )
              )
                  .toList(),
            ])

          ));
    });

}

class CHY_Packet{
  String sn='',id='';
  // ignore: non_constant_identifier_names
  double T1=69854740,T2=69854740; // 69854740 表示 尚未初始化
  // ignore: non_constant_identifier_names
  int year=0, month=0, day=0, fontsize=0, MainScreen = 0;
  int Type=0,Unit=0,Hold=0,MaxMin=0,hour=0,min=-1,sec=0,Batt=0,ViewMode=0,isSaveLog=0,t1flag=0,logflag=0,logSave = 0,showLogSave = 0, showOffset = 0, loggingSaveNum = 0, loggingFlag = 0,bleConnState = 0;
  // ignore: non_constant_identifier_names
  double Press=0,humi=0,Baro=0;
  // ignore: non_constant_identifier_names
  int recTime=0;
  CHY_Packet();
  //CHY_Packet(this.T1,this.T2,this.Type,this.Unit,this.Hold,this.MaxMin);
  //CHY_Packet.thermo(this.recTime,this.T1,this.T2,this.Type,this.Unit,this.Hold,this.MaxMin,this.year,this.month,this.day,this.fontsize,this.ViewMode,this.t1flag);
  CHY_Packet.thermoOld(this.recTime,this.T1,this.T2,this.Type,this.Unit,this.Hold,this.MaxMin,this.year,this.month,this.day,this.fontsize,this.ViewMode,this.t1flag);
  CHY_Packet.thermo(this.recTime,this.T1,this.T2,this.Type,this.Unit,this.Hold,this.MaxMin,this.hour,this.min,this.sec,this.ViewMode, this.MainScreen,this.t1flag,this.isSaveLog,this.logSave,this.showOffset, this.loggingFlag, this.loggingSaveNum,this.showLogSave,this.bleConnState);
  CHY_Packet.jl3pr(this.recTime,this.Press, this.humi, this.Baro);
}

var _useruplinkIntervalBuff = ['15 sec', '30 sec', '10 min', '1 hour' ];
Future showuplinkintervalDialog( {required context, required title}){
  int optidx=2;
  return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(content: SizedBox(height: 160,child: Column(children: [
          Text(title,style: TextStyle(fontSize: 32,),softWrap: false,),
          Center(child:   SizedBox(height: 60,child: WheelPicker(
            items: _useruplinkIntervalBuff,
            initialIndex: 2,
            onSelectedItemChanged: (index) {
              optidx =index;
              print("選擇了第 $optidx 項");
            },
          ))),
          TextButton(onPressed: (){
            Navigator.of(context).pop(optidx); // 回傳 1
          }, child: Text("confirm"))

        ])));});
}

var _userIntervalBuff = ['OFF', '10 sec', '30 sec', '60 sec', '300 sec' ];
Future showintervalDialog( {required context, required title}){
  int optidx=2;
   return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(content: SizedBox(height: 160,child: Column(children: [
          Text(title,style: TextStyle(fontSize: 32,),softWrap: false,),
          Center(child:   SizedBox(height: 60,child: WheelPicker(
            items: _userIntervalBuff,
            initialIndex: 2,
            onSelectedItemChanged: (index) {
              optidx =index;
              print("選擇了第 $optidx 項");
            },
          ))),
          TextButton(onPressed: (){
            Navigator.of(context).pop(optidx); // 回傳 1
          }, child: Text("confirm"))

        ])));});
}

String byteToHexString(buf){
  String res= "";
  buf.forEach((e){
    res+= e.toRadixString(16);
  });
  return res;
}