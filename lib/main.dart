import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'Page/page_ConnectionTabPage.dart';
import 'Widget_Function.dart';
import 'ble_device_connector.dart';
import 'ble_device_interactor.dart';
import 'ble_scanner.dart';
import 'ble_status_monitor.dart';
import 'package:geolocator/geolocator.dart';
class GpsProvider with ChangeNotifier {
  bool _isHighAccuracy = false;
  bool get isHighAccuracy => _isHighAccuracy;

  Future<void> checkAccuracyStatus() async {
    // 檢查 iOS 14+ 或 Android 的定位精確度狀態
    LocationAccuracyStatus status = await Geolocator.getLocationAccuracy();
    _isHighAccuracy = (status == LocationAccuracyStatus.precise);

    // 核心：必須調用此方法，Consumer 才會接收到通知並刷新 UI
    notifyListeners();
  }
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
  var status = await Permission.storage.status;
  if (status.isDenied) {
    // 權限被拒絕
    if (await Permission.storage.request().isPermanentlyDenied) {
      // 使用者勾選「不再詢問」後拒絕，導向到設定頁面
      await openAppSettings();
    } else {
      // 權限請求失敗，提示使用者
      // 可在此處顯示一個對話框，告知使用者權限取得失敗
    }
  } else if (status.isGranted) {
    // 權限已授權
    // 開始執行需要權限的操作
  }
}
void requestStoragePermission() async {
  // 檢查權限狀態

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
    ChangeNotifierProvider(create: (_) => GpsProvider()),
  ], child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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

  // late TextEditingController _controller;


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    mBleDeviceConnector = Provider.of<BleDeviceConnector>(context, listen: false);
    mBleDeviceInteractor = Provider.of<BleDeviceInteractor>(context, listen: false);
    // mConnectionStateUpdate = Provider.of<ConnectionStateUpdate>(context, listen: false);
    mBleScanner = Provider.of<BleScanner>(context, listen: false);

    // openfile();
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

  @override
  void dispose() {
    super.dispose();
    print("Probe dispose");
  }



  int filteridx = 0;
  List<String> _markupFilter = [];
  BleStatus mBLEStat = BleStatus.unknown;
  Map<String, DiscoveredDevice> mblelist = {};
  Map<String, CHY_Packet> mbeaconlist = {};

  String connectid = "";

  var stat = DeviceConnectionState.disconnected;
  @override
  Widget build(BuildContext context) => Consumer4<ConnectionStateUpdate,BleScannerState,BleStatus,GpsProvider>(
      builder: (_, mConnectionStateUpdate,bleScannerState,status,mpsProvider, __) {
        if( status == BleStatus.ready){
          //  print("bleScannerState.scanIsPause {${mblescanner.state}");
          if(bleScannerState.scanIsPause>1){///應該只會在藍芽關閉->啟動時才會遇到,app啟動時應該要會自動搜尋
            print("log scan automacally.");
            mBleScanner.startScan([]);

          }
        }
        if(mConnectionStateUpdate.connectionState == DeviceConnectionState.connected&&stat!=DeviceConnectionState.connected){

        }else if(mConnectionStateUpdate.connectionState == DeviceConnectionState.disconnected&&stat!=DeviceConnectionState.disconnected) {

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
            title: Text("V20260204"),
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
            child: mConnectionStateUpdate.connectionState == DeviceConnectionState.connected ?
            ConnectionTabPage(connectid:connectid):


              ///目前 Beacon 每次只有一個,先加入list在做物件
              //  print("scan stat ${bleScannerState.scanIsPause}///${bleScannerState.scanIsInProgress} ");
            status != BleStatus.ready
                ? Center(
                child:
                status == BleStatus.locationServicesDisabled
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.blue,
                  ),
                  Flexible(child: Text("Please enable Locations on your device to continue."))
                ])
                    : mpsProvider.isHighAccuracy?const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                    Icons.not_listed_location,
                    color: Colors.blue,
                  ),
                  Flexible(child: Text("Please enable Locations high accuracy on your device to continue."))
                ]):const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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

