import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
// import 'dart:nativewrappers/_internal/vm/lib/typed_data_patch.dart';

import 'package:convert/convert.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../Widget_Function.dart';
import '../ble_device_connector.dart';
import '../ble_device_interactor.dart';

class ConnectionTabPage extends StatefulWidget {
  final String connectid;

  const ConnectionTabPage({super.key, required this.connectid});

  @override
  State<StatefulWidget> createState() => _ConnectionTabPage();
}

class _ConnectionTabPage extends State<ConnectionTabPage> with TickerProviderStateMixin {
  late TabController _tabController;

  late BleDeviceConnector mBleDeviceConnector;
  late BleDeviceInteractor mBleDeviceInteractor;
  late QualifiedCharacteristic writecharacteristic, readcharacteristic;

  late ConnectionStateUpdate mConnectionStateUpdate;
  StreamSubscription<List<int>>? subscribeStream;

  int sensordata1_8idx = 2, metadata1_8idx = 2, status1_8idx = 2, hwperformance1_8idx = 2, hwerror1_8idx = 2;
  int sensordata1_3idx = 1, metadata1_3idx = 1, status1_3idx = 1, hwperformance1_3idx = 1, hwerror1_3idx = 1;
  int rssiVal = 0;

  final TextEditingController wifissidcontrol = TextEditingController();
  final TextEditingController wifipasscontrol = TextEditingController();
  final TextEditingController timestampaligncontrol = TextEditingController();
  final TextEditingController aligntimebuff = TextEditingController();
  final List<int> alignhextimebuff = [0, 0, 0, 0, 0, 0];
  final TextEditingController awsendpointcontrol = TextEditingController();
  final TextEditingController setsncontrol = TextEditingController();
  final TextEditingController forwarduplinkcontrol = TextEditingController();
  final TextEditingController commissiondatecontrol = TextEditingController();
  final TextEditingController calibrationdatecontrol = TextEditingController();
  final TextEditingController iotendpointcontrol = TextEditingController();
  final TextEditingController iotmqtttopiccontrol = TextEditingController();
  final TextEditingController manufactorydatecontrol = TextEditingController();

  List<int> _calibrationDateBuf = [0, 0, 0, 0], _commissionDateBuf = [0, 0, 0, 0], setSNBuf = [0, 0, 0, 0], setManufacturingBuf = [0, 0, 0, 0];

  List<String> readBuffer = [];
  List<Map<String, dynamic>> _jsonLogObj = [];

  List<int> _cmdToBLE(int op, int op1, List<int> buf) {
    List<int> _CmdBuff = [0x23, 0, 0x30 + op, 0x30 + op1] + buf;
    // while(_CmdBuff.length<31){_CmdBuff.add(0);}
    int sumcks = 0;
    _CmdBuff.add(sumcks);
    _CmdBuff.add(0x0d);
    _CmdBuff.add(0x0a);
    _CmdBuff[1] = _CmdBuff.length;
    for (int i = 0; i < _CmdBuff.length - 2; i++) {
      sumcks = sumcks + _CmdBuff[i];
    }
    _CmdBuff[_CmdBuff.length - 3] = sumcks;

    print("_CmdBuff ${_CmdBuff.toList().toString()}");
    return _CmdBuff;
  }

  String checkinterval(interval) {
    switch (interval) {
      case 0x0:
        return "interval: 15 sec";
        break;
      case 0x1:
        return "interval: 30 sec";
        break;
      case 0x2:
        return "interval: 10 min";
        break;
      case 0x3:
        return "interval: 1 hour";
        break;
      default:
        return "NaN";
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    mBleDeviceConnector = Provider.of<BleDeviceConnector>(context, listen: false);
    mBleDeviceInteractor = Provider.of<BleDeviceInteractor>(context, listen: false);
    writecharacteristic = mBleDeviceConnector.writecharacteristic;
    readcharacteristic = mBleDeviceConnector.readcharacteristic;

    _tabController = TabController(length: 2, vsync: this);
    // mBleDeviceConnector.state
    rssilooptimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      mConnectionStateUpdate = Provider.of<ConnectionStateUpdate>(context, listen: false);
      if(mConnectionStateUpdate.connectionState == DeviceConnectionState.connected){
        mBleDeviceConnector.getRssi(widget.connectid).then((onValue) {
          rssiVal = onValue;
          setState(() {});
        });
      }

    });

    subscribeCharacteristic();
  }

  Future<void> subscribeCharacteristic() async {

    subscribeStream = mBleDeviceConnector.readBuffStream.listen((event) async {
      // subscribeStream =
      print("meter res : ${event.toString()}");
      String res = "";
      String opCode = "${event[2]-48}-${event[3]-48}";
      print("opCode:$opCode");
      try {

        ///7.10格式為全部ascii
      if(event.length>36) {

         bool isNotSync = String.fromCharCodes(event.sublist(4, 24)).contains("Not Sync to Cloud");
        if (isDateTime(String.fromCharCodes(event.sublist(4, 24)))||isNotSync) {
          List<dynamic> payloaddata = [];
          print("decodeD start");
          // var asciiPart = event.takeWhile((b) => b != 0).toList();
          // print(String.fromCharCodes(event.sublist(24, event.length-7)));
          var decodeD = base64.decode(String.fromCharCodes(event.sublist(24, event.length-3)));

          print("decodeD LEN ${decodeD.length}, $decodeD");
          if(isNotSync){
            payloaddata.add("Not Sync to Cloud");
          }else {
            payloaddata.add(String.fromCharCodes(event.sublist(4, 24)));
          }
          // payloaddata.add(parseIntList(event.sublist(4, event.length-3)).text);
          payloaddata.add(decodeD[0] << 8 | decodeD[1]); //(event.sublist(24,26) as Uint8);
          payloaddata.add(
              "${decodeD[2].toRadixString(16).padLeft(2, '0')}${decodeD[3].toRadixString(16).padLeft(2, '0')}${decodeD[4].toRadixString(16).padLeft(2, '0')}${decodeD[5]
                  .toRadixString(16)
                  .padLeft(2, '0')}");
          for (var i = 6; i < decodeD.length; i += 2) {
            var value  = decodeD[i] << 8 | decodeD[i + 1];
            if (value & 0x8000 != 0) { // 如果最高位是 1
              value = value - 0x10000;
            }
            print(value);
            payloaddata.add(value); //(event.sublist(i, i+2) as Uint8);
          }
          print("payloaddata LEN ${payloaddata.length}");

          if (payloaddata.length == 18) {
            _jsonLogObj.insert(0, {
              "MT": payloaddata[0],
              "IU": payloaddata[1],
              "IUSN": payloaddata[2],
              "IUOT": payloaddata[3] / 10,
              "IUORH": payloaddata[4] / 10,
              "IUOP": payloaddata[5],
              "IUPV": payloaddata[6] / 10,
              "IUBC": payloaddata[7] / 10,
              "IUIC": payloaddata[8] / 10,
              "IUPRCSP": payloaddata[9] / 1000,
              "IUPOSP": payloaddata[10] / 1000,
              "IUSAV": payloaddata[11],
              "IUST": payloaddata[12] / 10,
              "IUSRH": payloaddata[13] / 10,
              "IUPRFSP": payloaddata[14] / 1000,
              "IUPOFSP": payloaddata[15] / 1000,
              "IUSRT": payloaddata[16] / 10,
              "IUSRRH": payloaddata[17] / 10,
            });
          } else if (payloaddata.length == 17) {
            _jsonLogObj.insert(0, {
              "MT": payloaddata[0],
              "OU": payloaddata[1],
              "OUSN": payloaddata[2],
              "OUOT": payloaddata[3] / 10,
              "OUORH": payloaddata[4] / 10,
              "OUOP": payloaddata[5],
              "OUPV": payloaddata[6] / 10,
              "OUFC": payloaddata[7] / 10,
              "OUCC": payloaddata[8] / 10,
              "OUACT": payloaddata[9] / 10,
              "OUARH": payloaddata[10] / 10,
              "OUTCT": payloaddata[11] / 10,
              "OUTRH": payloaddata[12] / 10,
              "OURHPT": payloaddata[13] / 10,
              "OURLPT": payloaddata[14] / 10,
              "OURHP": payloaddata[15] / 10,
              "OURLP": payloaddata[16] / 10,
            });
          } else if (payloaddata.length == 28) {
            _jsonLogObj.insert(0, {
              "MT": payloaddata[0],
              "CU": payloaddata[1],
              "CUSN": payloaddata[2],
              "CUOT": payloaddata[3] / 10,
              "CUORH": payloaddata[4] / 10,
              "CUOP": payloaddata[5],
              "CUPV": payloaddata[6] / 10,
              "CUBC": payloaddata[7] / 10,
              "CUIC": payloaddata[8] / 10,
              "CUPRCSP": payloaddata[9] / 1000,
              "CUPOSP": payloaddata[10] / 1000,
              "CUSAV": payloaddata[11],
              "CUST": payloaddata[12] / 10,
              "CUSRH": payloaddata[13] / 10,
              "CUPRFSP": payloaddata[14] / 1000,
              "CUPOFSP": payloaddata[15] / 1000,
              "CUSRT": payloaddata[16] / 10,
              "CUSRRH": payloaddata[17] / 10,
              "CUFC": payloaddata[18] / 10,
              "CUCC": payloaddata[19] / 10,
              "CUACT": payloaddata[20] / 10,
              "CUARH": payloaddata[21] / 10,
              "CUTCT": payloaddata[22] / 10,
              "CUTRH": payloaddata[23] / 10,
              "CURHPT": payloaddata[24] / 10,
              "CURLPT": payloaddata[25] / 10,
              "CURHP": payloaddata[26] / 10,
              "CURLP": payloaddata[27] / 10,
            });
          }



            if (decodeD.length > 31) {
              // res =_jsonLogObj[0].toString();
              res = String.fromCharCodes(event.sublist(4, event.length-3));

              writeFile(_jsonLogObj[0].toString());
            }


          if (_jsonLogObj.length > 100) {
            _jsonLogObj.removeLast();
          }
        } else {
          res = String.fromCharCodes(event.sublist(4, event.length-3));
          // res = parseIntList(event.sublist(4, event.length-3)).text;
        }
      }else {
        // res = parseIntList(event.sublist(4, event.length-3)).text;

        res = String.fromCharCodes(event.sublist(4, event.length-3));
        if(opCode=="4-0"){
          await Future.delayed(Duration(seconds: 1));
          mBleDeviceConnector.disconnect(widget.connectid);
          subscribeStream?.cancel();
        }
      }

///7.9格式依照封包解析
        // switch (opCode) {
        //   case "1-0":
        //     res =
        //         "mode: ${event[4] == 0x31
        //             ? "Wifi"
        //             : event[4] == 0x32
        //             ? "5G"
        //             : "Wifi"}\n"
        //         "${checkinterval(0)}\n"
        //         "${String.fromCharCodes(event.sublist(7, 7 + event[6]))}\n"
        //         "${String.fromCharCodes(event.sublist(7 + event[6] + 1, 7 + event[6] + 1 + event[7 + event[6]]))}\n"
        //         "${String.fromCharCodes(event.sublist(7 + event[6] + 1 + event[7 + event[6]], event.length - 2))}\n"
        //         "";
        //     break;
        //   case "1-1":
        //     res =
        //         "mode: ${event[4] == 0x31
        //             ? "Wifi"
        //             : event[4] == 0x32
        //             ? "5G"
        //             : "Wifi"}"; //String.fromCharCodes(event.sublist(4,event.length-3));
        //     break;
        //   case "1-2":
        //     switch (event[4]) {
        //       case 0:
        //         res = "OK";
        //         break;
        //       case 1:
        //         res = "High-side pressure is working";
        //         break;
        //       case 2:
        //         res = "Low-side pressure is working";
        //         break;
        //       case 3:
        //         res = "No High-side pressure";
        //         break;
        //       case 4:
        //         res = "No Low-side pressure";
        //         break;
        //       case 5:
        //         res = "No Supply Pre Coil sensor";
        //         break;
        //       case 6:
        //         res = "No Supply Post Coil sensor";
        //         break;
        //       case 7:
        //         res = "No Supply Air Velocity sensor";
        //         break;
        //       case 8:
        //         res = "No Return Pre Filter sensor";
        //         break;
        //       case 9:
        //         res = "No Return Post Filter sensor";
        //         break;
        //       default:
        //         res = "NaN";
        //     }
        //     break;
        //   case "1-3":
        //     res = checkinterval(event[4]);
        //     break;
        //   case "1-4": //wifi setting
        //
        //     break;
        //   case "1-5":
        //     res = "timestamp: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
        //     break;
        //   case "1-6": //return to the default settings
        //     res = " ${event[4]}";
        //     break;
        //   case "1-7": //return to the default settings
        //     res = " ${event[4]}";
        //     break;
        //   case "1-8": //return to the default settings
        //     res = " [${event[4]},${event[5]},${event[6]},${event[7]},${event[8]}]";
        //     break;
        //   case "2-0":
        //     res =
        //         "fw: ${event[4]}.${event[5]}.${event[6]}\n"
        //         "cal: ${event[7]}${event[8]}${event[9]}${event[10]}\n"
        //         "commission: ${event[11]}${event[12]}${event[13]}${event[14]}\n"
        //         "Wifi Mac: ${hex.encode(event.sublist(15, 21))}\n"
        //         "BLE Mac: ${hex.encode(event.sublist(21, 27))}\n"
        //         "Cellular IMEI: ${hex.encode(event.sublist(27, 35))}\n"
        //         "Lora Eui: ${hex.encode(event.sublist(35, 43))}\n"
        //         "eSim:\n"
        //         "Secret key: ${String.fromCharCodes(event.sublist(43, 59))}\n"
        //         "ICC ID: ${String.fromCharCodes(event.sublist(59, 69))}\n"
        //         "UPC: ${String.fromCharCodes(event.sublist(69, 91))}\n"
        //         "IMSI: ${String.fromCharCodes(event.sublist(91, 99))}\n"
        //         "UPC: ${String.fromCharCodes(event.sublist(69, 91))}\n"
        //         "MCU Speed: ${event[91]}\n"
        //         "Flash Memory: ${event[92] << 24 | event[93] << 16 | event[94] << 8 | event[95]}\n";
        //     break;
        //   case "2-1": //return to the default settings
        //     res = "calibration: ${byteToHexString(event.sublist(4, event.length - 3))}";
        //     break;
        //   case "2-2": //return to the default settings
        //     res = "commisson: ${byteToHexString(event.sublist(4, event.length - 3))}";
        //     break;
        //   case "3-0": //return to the default settings
        //     res = "forward: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
        //     break;
        //   case "3-1": //return to the default settings
        //     res = "getdata: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
        //     break;
        //   case "4-0":
        //   case "5-0":
        //     var eplen = event[4]-48;
        //     var tplen = event[event[4]-48 + 5]-48;
        //
        //     // print("ep---: ${String.fromCharCodes(event.sublist(5, event.length))}");
        //
        //     String text = String.fromCharCodes(event.sublist(4, event.length));
        //    var  resbuf = text.split(RegExp(r'\r?\n')).where((s) => s.isNotEmpty).toList();
        //     print(resbuf);
        //     res= "";
        //
        //     for (var e in resbuf) {
        //       res+="$e\n";
        //     }
        //         // res =
        //         // "endpoint: ${String.fromCharCodes(event.sublist(5, 5 + eplen))}\n"
        //         // "topic: ${String.fromCharCodes(event.sublist(5 + eplen + 1, eplen + 5 + 1 + tplen))}\n"
        //         // "s/n:${String.fromCharCodes(event.sublist(eplen + 5 + 1 + tplen, eplen + 5 + 1 + tplen + 4))}\n"
        //         // "manufacturing date: ${String.fromCharCodes(event.sublist(eplen + 5 + 1 + tplen + 4, eplen + 5 + 1 + tplen + 4 + 4))}";
        //     break;
        //   case "5-1":
        //     res = "endpoint: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
        //     break;
        //   case "5-2":
        //     res = "topic: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
        //     break;
        //   case "5-3":
        //     res = "SN: ${byteToHexString(event.sublist(4, event.length - 3))}";
        //     break;
        //   case "5-4":
        //     res = "topic: ${byteToHexString(event.sublist(4, event.length - 3))}";
        //     break;
        //   default:
        //     var nowtimt = DateTime.now();
        //     res = "${nowtimt.hour}:${nowtimt.minute}:${nowtimt.second}-other: ${String.fromCharCodes(event.sublist(4, event.length - 3))}";
        //     print("opCode:$opCode");
        //     if(event.length>30) {
        //       List<dynamic> payloaddata = [];
        //
        //
        //       var decodeD = base64.decode(String.fromCharCodes(event.sublist(24, event.length)));
        //
        //
        //       if(isDateTime(String.fromCharCodes(event.sublist(0, 24)))) {
        //         print("decodeD LEN ${decodeD.length}, $decodeD");
        //         payloaddata.add(String.fromCharCodes(event.sublist(0, 24)));
        //         payloaddata.add(decodeD[0] << 8 | decodeD[1]); //(event.sublist(24,26) as Uint8);
        //         payloaddata.add(
        //             "${decodeD[2].toRadixString(16).padLeft(2, '0')}${decodeD[3].toRadixString(16).padLeft(2, '0')}${decodeD[4].toRadixString(16).padLeft(2, '0')}${decodeD[5]
        //                 .toRadixString(16)
        //                 .padLeft(2, '0')}");
        //         for (var i = 6; i < decodeD.length; i += 2) {
        //           print(decodeD[i] << 8 | decodeD[i + 1]);
        //           payloaddata.add(decodeD[i] << 8 | decodeD[i + 1]); //(event.sublist(i, i+2) as Uint8);
        //         }
        //         print("payloaddata LEN ${payloaddata.length}");
        //
        //         if (payloaddata.length == 18) {
        //           _jsonLogObj.insert(0, {
        //             "MT": payloaddata[0],
        //             "IU": payloaddata[1],
        //             "IUSN": payloaddata[2],
        //             "IUOT": payloaddata[3] / 10,
        //             "IUORH": payloaddata[4] / 10,
        //             "IUOP": payloaddata[5],
        //             "IUPV": payloaddata[6] / 10,
        //             "IUBC": payloaddata[7] / 10,
        //             "IUIC": payloaddata[8] / 10,
        //             "IUPRCSP": payloaddata[9] / 1000,
        //             "IUPOSP": payloaddata[10] / 1000,
        //             "IUSAV": payloaddata[11],
        //             "IUST": payloaddata[12] / 10,
        //             "IUSRH": payloaddata[13] / 10,
        //             "IUPRFSP": payloaddata[14] / 1000,
        //             "IUPOFSP": payloaddata[15] / 1000,
        //             "IUSRT": payloaddata[16] / 10,
        //             "IUSRRH": payloaddata[17] / 10,
        //           });
        //         } else if (payloaddata.length == 17) {
        //           _jsonLogObj.insert(0, {
        //             "MT": payloaddata[0],
        //             "OU": payloaddata[1],
        //             "OUSN": payloaddata[2],
        //             "OUOT": payloaddata[3] / 10,
        //             "OUORH": payloaddata[4] / 10,
        //             "OUOP": payloaddata[5],
        //             "OUPV": payloaddata[6] / 10,
        //             "OUFC": payloaddata[7] / 10,
        //             "OUCC": payloaddata[8] / 10,
        //             "OUACT": payloaddata[9] / 10,
        //             "OUARH": payloaddata[10] / 10,
        //             "OUTCT": payloaddata[11] / 10,
        //             "OURHPT": payloaddata[12] / 10,
        //             "OURLPT": payloaddata[13] / 10,
        //             "OURHP": payloaddata[14] / 10,
        //             "OURLP": payloaddata[15] / 10,
        //           });
        //         } else if (payloaddata.length == 28) {
        //           _jsonLogObj.insert(0, {
        //             "MT": payloaddata[0],
        //             "CU": payloaddata[1],
        //             "CUSN": payloaddata[2],
        //             "CUOT": payloaddata[3] / 10,
        //             "CUORH": payloaddata[4] / 10,
        //             "CUOP": payloaddata[5],
        //             "CUPV": payloaddata[6] / 10,
        //             "CUBC": payloaddata[7] / 10,
        //             "CUIC": payloaddata[8] / 10,
        //             "CUPRCSP": payloaddata[9] / 1000,
        //             "CUPOSP": payloaddata[10] / 1000,
        //             "CUSAV": payloaddata[11],
        //             "CUST": payloaddata[12] / 10,
        //             "CUSRH": payloaddata[13] / 10,
        //             "CUPRFSP": payloaddata[14] / 1000,
        //             "CUPOFSP": payloaddata[15] / 1000,
        //             "CUSRT": payloaddata[16] / 10,
        //             "CUSRRH": payloaddata[17] / 10,
        //             "CUFC": payloaddata[18] / 10,
        //             "CUCC": payloaddata[19] / 10,
        //             "CUACT": payloaddata[20] / 10,
        //             "CUARH": payloaddata[21] / 10,
        //             "CUTCT": payloaddata[22] / 10,
        //             "CUTRH": payloaddata[23] / 10,
        //             "CURHPT": payloaddata[24] / 10,
        //             "CURLPT": payloaddata[25] / 10,
        //             "CURHP": payloaddata[26] / 10,
        //             "CURLP": payloaddata[27] / 10,
        //           });
        //         }
        //         if (decodeD.length > 60) {
        //           writeFile(_jsonLogObj[0].toString());
        //         }
        //         if (_jsonLogObj.length > 100) {
        //           _jsonLogObj.removeLast();
        //         }
        //       }
        //     }
        //     break;
        // }
      } catch (e) {
        res = e.toString();
        print("err: $res");
      }
      readBuffer.insert(0, res);
      if (readBuffer.length > 10000) {
        readBuffer.removeAt(readBuffer.length - 1);
      }
      setState(() {});
    });
  }

  ParsedStringResult parseIntList(List<int> bytes) {
    // 1️⃣ 轉成字串
    String text = String.fromCharCodes(bytes);

    // 2️⃣ 用正規抓出所有數字（含負號）
    final regex = RegExp(r'-?\d+');
    final numbers = regex
        .allMatches(text)
        .map((m) => int.parse(m.group(0)!))
        .toList();

    // 3️⃣ 判斷是否有負數
    bool hasNegative = numbers.any((n) => n < 0);

    return ParsedStringResult(
      text: text,
      numbers: numbers,
      hasNegative: hasNegative,
    );
  }

  // final dir = Directory('/storage/emulated/0/Download');
  Future<void> writeFile(String str) async {
    final dir = Directory('/storage/emulated/0/Download');
    // print('📁 檔案路徑: ${dir.path}');
    // await Directory(dir.path).create(recursive: true);
    //
    // final file = File('${dir.path}/test.txt');
    //
    //
    // int len = await file.length();
    // print("write ok ${len}");
    // await file.writeAsString(mode: FileMode.append, len>0?",$str":str);
    try {
      // final dir = await getApplicationDocumentsDirectory();
      print('📁 檔案路徑: ${dir.path}');
      await Directory(dir.path).create(recursive: true);

      var nowDate = DateTime.now();
      final file = File('${dir.path}/ov_log.txt');
      // final file = File('${dir.path}/ov_log_${nowDate.day}${nowDate.hour}.txt');
      // int len = await file.length();
      await file.writeAsString(mode: FileMode.append, "$str,");
      print('✅ 寫入成功: ${file.path}');
      print('檔案存在嗎？${await file.exists()}');
    } catch (e, st) {
      print('❌ 錯誤: $e');
      print(st);
    }
  }

  Timer rssilooptimer = Timer.periodic(const Duration(seconds: 1), (timer) {});

  @override
  void didUpdateWidget(covariant ConnectionTabPage oldWidget) {
    // TODO: implement didUpdateWidget
    super.didUpdateWidget(oldWidget);
    print("didUpdateWidget connectpage");
  }

  @override
  void dispose() {
    super.dispose();
    print("Probe dispose");

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
    if (rssilooptimer.isActive) {
      rssilooptimer.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Column(
      children: [
        TabBar(controller: _tabController, tabs: const [Tab(text: "Cmd"), Tab(text: "Log")]),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              var inputBuff = [];

                              // inputBuff.addAll([utf8.encode(_controller.text)]);
                              // ///寫入緩衝區
                              // print(inputBuff);
                              // if(inputBuff.length>20) {
                              //   mBleDeviceInteractor.writeCharacterisiticWithResponse(mBleDeviceConnector.writecharacteristic, []);
                              // }
                              var event = List.generate(55, (index) => index);
                              event[6] = 17;
                              event[24] = 8;
                              var res =
                                  "mode: ${event[4] == 0x31
                                      ? "Wifi"
                                      : event[4] == 0x32
                                      ? "5G"
                                      : "Wifi"}\n"
                                  "${checkinterval(0x30)}\n"
                                  "${(event.sublist(7, 7 + event[6])).join()}\n"
                                  "${event.sublist(7 + event[6] + 1, 7 + event[6] + 1 + event[7 + event[6]]).join()}\n"
                                  "${event.sublist(7 + event[6] + 1 + event[7 + event[6]], event.length - 2).join()}\n"
                                  "";
                              //.toRadixString(16)
                              var sss = [0x12, 0x34, 0x56, 0x78];
                              String dfdd = "";
                              sss.forEach((e) {
                                dfdd += e.toRadixString(16);
                              });
                              print("send${dfdd}");
                              // print("send${mBleDeviceInteractor.writeCharacterisiticWithResponse(mBleDeviceConnector.writecharacteristic, [0x23,0x06,0x69,0x92,0x0D,0x0A])}");
                              setState(() {
                                // mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, [0x23,0x06,0x69,0x92,0x0D,0x0A]);
                              });
                            },
                            child: Text("0.0 test submit"),
                          ),
                          Divider(),
                          Text("1.user info"),
                          Card(
                            margin: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 0, [0]));
                                      }),
                                      child: Text("1.0 get user setting"),
                                    ),
                                  ],
                                ),
                                Text("backhual connection"),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal, // 指定為水平滾動

                                  child: Row(
                                    children: [
                                      ///get backhual connection
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 1, [0x0]));
                                        }),
                                        child: Text("1.1 set Wifi"),
                                      ),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 1, [0x1]));
                                        }),
                                        child: Text("1.1 set LoRa"),
                                      ),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 1, [0x2]));
                                        }),
                                        child: Text("1.1 5G"),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 2, [0]));
                                      }),
                                      child: Text("1.2 sensor zeroing"),
                                    ),
                                  ],
                                ),
                                Text("uplink interval"),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal, // 指定為水平滾動
                                  child: Row(
                                    children: [
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showuplinkintervalDialog(context: context, title: "sensor data").then((onValue) {
                                                setState(() {
                                                  sensordata1_3idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("SensorData"),
                                          ),
                                          Text("${_useruplinkIntervalBuff[sensordata1_3idx]}"),
                                        ],
                                      ),

                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showuplinkintervalDialog(context: context, title: "metadata").then((onValue) {
                                                setState(() {
                                                  metadata1_3idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("metaData"),
                                          ),
                                          Text("${_useruplinkIntervalBuff[metadata1_3idx]}"),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showuplinkintervalDialog(context: context, title: "Status").then((onValue) {
                                                setState(() {
                                                  status1_3idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("Status"),
                                          ),
                                          Text("${_useruplinkIntervalBuff[status1_3idx]}"),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showuplinkintervalDialog(context: context, title: "HW Performance").then((onValue) {
                                                setState(() {
                                                  hwperformance1_3idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("HW Performance"),
                                          ),
                                          Text("${_useruplinkIntervalBuff[hwperformance1_3idx]}"),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showuplinkintervalDialog(context: context, title: "HW Error").then((onValue) {
                                                setState(() {
                                                  hwerror1_3idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("HW Error"),
                                          ),
                                          Text("${_useruplinkIntervalBuff[hwerror1_3idx]}"),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: (() {
                                    mBleDeviceInteractor.writeCharacterisiticWithResponse(
                                      writecharacteristic,
                                      _cmdToBLE(1, 3, [sensordata1_3idx, metadata1_3idx, status1_3idx, hwperformance1_3idx, hwerror1_3idx]),
                                    );
                                  }),
                                  child: Text("1.3 submit"),
                                ),
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
                                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: wifissidcontrol,
                                        decoration: const InputDecoration(labelText: 'SSID', border: OutlineInputBorder()),
                                        onChanged: (text) {
                                          wifissidcontrol.text = text;
                                          print('Text changed: $text');
                                        },
                                        onSubmitted: (text) {
                                          print('Text submitted: $text');
                                        },
                                      ),
                                    ),
                                    //   ElevatedButton(onPressed: (){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1,4, wifissidcontrol.text.codeUnits));}, child: Text("submit"))
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: wifipasscontrol,
                                        decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                                        onChanged: (text) {
                                          wifipasscontrol.text = text;
                                          print('Text changed: $text');
                                        },
                                        onSubmitted: (text) {
                                          print('Text submitted: $text');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    mBleDeviceInteractor.writeCharacterisiticWithResponse(
                                      writecharacteristic,
                                      _cmdToBLE(
                                        1,
                                        4,
                                        [wifissidcontrol.text.codeUnits.length] +
                                            wifissidcontrol.text.codeUnits +
                                            [wifipasscontrol.text.codeUnits.length] +
                                            wifipasscontrol.text.codeUnits,
                                      ),
                                    );
                                  },
                                  child: Text("1.4 submit"),
                                ),

                                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),

                                ElevatedButton(
                                  onPressed: (() {
                                    DateTime nowT = DateTime.now().toUtc();

                                    mBleDeviceInteractor.writeCharacterisiticWithResponse(
                                      writecharacteristic,
                                      _cmdToBLE(1, 5, [nowT.year - 2000, nowT.month, nowT.day, nowT.hour, nowT.minute, nowT.second]),
                                    );
                                  }),
                                  child: Text("1.5 align"),
                                ),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 6, [0]));
                                      }),
                                      child: Text("1.6 return to the default settings"),
                                    ),
                                  ],
                                ),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
                                Text("BLE Advertisement Duration"),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal, // 指定為水平滾動
                                  child: Row(
                                    children: [
                                      //     ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, []));}), child: Text("get uplink interval")),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 7, [0x0]));
                                        }),
                                        child: Text("1.7 3 min"),
                                      ),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 7, [0x1]));
                                        }),
                                        child: Text("1.7 5 min"),
                                      ),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 7, [0x2]));
                                        }),
                                        child: Text("1.7 7 min"),
                                      ),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(1, 7, [0x3]));
                                        }),
                                        child: Text("1.7 10 min"),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
                                Text("BLE transmission interval"),

                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal, // 指定為水平滾動
                                  child: Row(
                                    children: [
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showintervalDialog(context: context, title: "sensor data").then((onValue) {
                                                setState(() {
                                                  sensordata1_8idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("SensorData"),
                                          ),
                                          Text("${_userIntervalBuff[sensordata1_8idx]}"),
                                        ],
                                      ),

                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showintervalDialog(context: context, title: "metadata").then((onValue) {
                                                setState(() {
                                                  metadata1_8idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("metaData"),
                                          ),
                                          Text("${_userIntervalBuff[metadata1_8idx]}"),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showintervalDialog(context: context, title: "Status").then((onValue) {
                                                setState(() {
                                                  status1_8idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("Status"),
                                          ),
                                          Text("${_userIntervalBuff[status1_8idx]}"),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showintervalDialog(context: context, title: "HW Performance").then((onValue) {
                                                setState(() {
                                                  hwperformance1_8idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("HW Performance"),
                                          ),
                                          Text("${_userIntervalBuff[hwperformance1_8idx]}"),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {
                                              showintervalDialog(context: context, title: "HW Error").then((onValue) {
                                                setState(() {
                                                  hwerror1_8idx = onValue;
                                                });
                                              });
                                            },
                                            child: Text("HW Error"),
                                          ),
                                          Text("${_userIntervalBuff[hwerror1_8idx]}"),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: (() {
                                    mBleDeviceInteractor.writeCharacterisiticWithResponse(
                                      writecharacteristic,
                                      _cmdToBLE(1, 8, [sensordata1_8idx, metadata1_8idx, status1_8idx, hwperformance1_8idx, hwerror1_8idx]),
                                    );
                                  }),
                                  child: Text("1.8 submit"),
                                ),
                              ],
                            ),
                          ),
                          Divider(),
                          Text("2.box info"),
                          Card(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(2, 0, [0]));
                                      }),
                                      child: Text("2.0 get box info"),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        // 呼出数字键盘
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly, // 只允许数字输入
                                        ],
                                        controller: calibrationdatecontrol,
                                        decoration: const InputDecoration(labelText: 'calibration date', border: OutlineInputBorder()),
                                        onChanged: (text) {
                                          if (text.length == 8) {
                                            _calibrationDateBuf[0] = int.parse(text.substring(0, 2), radix: 16);
                                            _calibrationDateBuf[1] = int.parse(text.substring(2, 4), radix: 16);
                                            _calibrationDateBuf[2] = int.parse(text.substring(4, 6), radix: 16);
                                            _calibrationDateBuf[3] = int.parse(text.substring(6, 8), radix: 16);
                                          }
                                          print('Text changed: $_calibrationDateBuf');
                                        },
                                        onSubmitted: (text) {
                                          print('Text submitted: $text');
                                        },
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(2, 1, _calibrationDateBuf));
                                      }),
                                      child: Text("2.1    cal    "),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        // 呼出数字键盘
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly, // 只允许数字输入
                                        ],
                                        controller: commissiondatecontrol,
                                        decoration: const InputDecoration(labelText: 'commission date', border: OutlineInputBorder()),
                                        onChanged: (text) {
                                          if (text.length == 8) {
                                            _commissionDateBuf[0] = int.parse(text.substring(0, 2), radix: 16);
                                            _commissionDateBuf[1] = int.parse(text.substring(2, 4), radix: 16);
                                            _commissionDateBuf[2] = int.parse(text.substring(4, 6), radix: 16);
                                            _commissionDateBuf[3] = int.parse(text.substring(6, 8), radix: 16);
                                          }
                                          print('Text changed: $text');
                                        },
                                        onSubmitted: (text) {
                                          print('Text submitted: $text');
                                        },
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(2, 2, _commissionDateBuf));
                                      }),
                                      child: Text("2.2 submit"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

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
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: (() async {
                                  mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(4, 0, [0]));
                                  await Future.delayed(Duration(seconds: 3));
                                  mBleDeviceConnector.disconnect(widget.connectid);
                                  subscribeStream?.cancel();

                                }),
                                child: Text("4.0 reboot"),
                              ),
                            ],
                          ),

                          ///===5========================================
                          Divider(),
                          Text("developer"),
                          Card(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 0, [0]));
                                      }),
                                      child: Text("5.0 get dev settings"),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: iotendpointcontrol,
                                        decoration: const InputDecoration(labelText: 'iot point', border: OutlineInputBorder()),
                                        onChanged: (text) {
                                          iotendpointcontrol.text = text;
                                          print('Text changed: $text');
                                        },
                                        onSubmitted: (text) {
                                          print('Text submitted: $text');
                                        },
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 1, iotendpointcontrol.text.codeUnits));
                                      }),
                                      child: Text("5.1 submit"),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: iotmqtttopiccontrol,
                                        decoration: const InputDecoration(labelText: 'iot topic', border: OutlineInputBorder()),
                                        onChanged: (text) {
                                          iotmqtttopiccontrol.text = text;
                                          print('Text changed: $text');
                                        },
                                        onSubmitted: (text) {
                                          print('Text submitted: $text');
                                        },
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: (() {
                                        print("${iotmqtttopiccontrol.text.codeUnits}");
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 2, iotmqtttopiccontrol.text.codeUnits));
                                      }),
                                      child: Text("5.2 submit"),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: setsncontrol,
                                        decoration: const InputDecoration(labelText: 's/n', border: OutlineInputBorder()),
                                        onChanged: (text) {
                                          if (text.length == 8) {
                                            setSNBuf[0] = int.parse(text.substring(0, 2), radix: 16);
                                            setSNBuf[1] = int.parse(text.substring(2, 4), radix: 16);
                                            setSNBuf[2] = int.parse(text.substring(4, 6), radix: 16);
                                            setSNBuf[3] = int.parse(text.substring(6, 8), radix: 16);
                                          }

                                          print('Text changed: $text');
                                        },
                                        onSubmitted: (text) {
                                          print('Text submitted: $text');
                                        },
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 3, setSNBuf));
                                      }),
                                      child: Text("5.3 submit"),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: manufactorydatecontrol,
                                        decoration: const InputDecoration(labelText: 'manufacturing date', border: OutlineInputBorder()),
                                        onChanged: (text) {
                                          if (text.length == 8) {
                                            setManufacturingBuf[0] = int.parse(text.substring(0, 2), radix: 16);
                                            setManufacturingBuf[1] = int.parse(text.substring(2, 4), radix: 16);
                                            setManufacturingBuf[2] = int.parse(text.substring(4, 6), radix: 16);
                                            setManufacturingBuf[3] = int.parse(text.substring(6, 8), radix: 16);
                                          }

                                          print('Text changed: $text');
                                        },
                                        onSubmitted: (text) {
                                          print('Text submitted: $text');
                                        },
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: (() {
                                        mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 4, setManufacturingBuf));
                                      }),
                                      child: Text("5.4 submit"),
                                    ),
                                  ],
                                ),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
                                Text("change role"),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal, // 指定為水平滾動
                                  child: Row(
                                    children: [
                                      //     ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, []));}), child: Text("get uplink interval")),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 5, [0]));
                                        }),
                                        child: Text("5.5 indoor"),
                                      ),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 5, [1]));
                                        }),
                                        child: Text("5.5 outdoor"),
                                      ),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 5, [2]));
                                        }),
                                        child: Text("5.5 combined"),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
                                Text("dual uplink mode"),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal, // 指定為水平滾動
                                  child: Row(
                                    children: [
                                      //     ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(1, 3, []));}), child: Text("get uplink interval")),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 6, [0]));
                                        }),
                                        child: Text("5.6 off"),
                                      ),
                                      ElevatedButton(
                                        onPressed: (() {
                                          mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(5, 6, [1]));
                                        }),
                                        child: Text("5.6 on"),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ElevatedButton(
                          //   onPressed: (() {
                          //     mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic, _cmdToBLE(6, 1, [0]));
                          //   }),
                          //   child: Text("6.1 undefined command"),
                          // ),

                          // Row(children: [
                          //   ElevatedButton(onPressed: ((){mBleDeviceInteractor.writeCharacterisiticWithResponse(writecharacteristic,_cmdToBLE(6, 2, []));}), child: Text("get fw")),
                          // ],),
                        ],
                      ),
                    ),
                  ),
                  Divider(),
                  Text("received from BLE device, RSSI: $rssiVal "),

                  SizedBox(
                    height: 200,
                    child:
                    // ReorderableListView(onReorder: (int oldIndex, int newIndex) {
                    //   setState(() {
                    //     if (newIndex > oldIndex) newIndex -= 1;
                    //     final item = readBuffer.removeAt(oldIndex);
                    //     readBuffer.insert(newIndex, item);
                    //   });
                    // },
                    // children: [...readBuffer.map((e) => Text(e))],)
                    ListView(children: [...readBuffer.map((e) => Text(e, softWrap: true))]),
                  ),
                ],
              ),
              Column(children: [

                Expanded(child: ListView(children: [..._jsonLogObj.map((e)=>Card(child: Text(e.toString(),softWrap: true)))]))]),
      ],
    ))]);
  }
}

var _useruplinkIntervalBuff = ['15 sec', '30 sec', '10 min', '1 hour'];

Future showuplinkintervalDialog({required context, required title}) {
  int optidx = 2;
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          height: 160,
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 32), softWrap: false),
              Center(
                child: SizedBox(
                  height: 60,
                  child: WheelPicker(
                    items: _useruplinkIntervalBuff,
                    initialIndex: 2,
                    onSelectedItemChanged: (index) {
                      optidx = index;
                      print("選擇了第 $optidx 項");
                    },
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(optidx); // 回傳 1
                },
                child: Text("confirm"),
              ),
            ],
          ),
        ),
      );
    },
  );
}

var _userIntervalBuff = ['OFF', '10 sec', '30 sec', '60 sec', '300 sec'];

Future showintervalDialog({required context, required title}) {
  int optidx = 2;
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          height: 160,
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 32), softWrap: false),
              Center(
                child: SizedBox(
                  height: 60,
                  child: WheelPicker(
                    items: _userIntervalBuff,
                    initialIndex: 2,
                    onSelectedItemChanged: (index) {
                      optidx = index;
                      print("選擇了第 $optidx 項");
                    },
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(optidx); // 回傳 1
                },
                child: Text("confirm"),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String byteToHexString(buf) {
  String res = "";
  buf.forEach((e) {
    res += e.toRadixString(16);
  });
  return res;
}
bool isDateTime(String text) {
  try {

    print("isDateTime ${text.replaceFirst("T", " ")}");
    DateTime.parse(text);
    return true;
  } catch (e) {
    print("isDateTime false");
    return false;
  }
}

class ParsedStringResult {
  final String text;       // 轉回的字串
  final List<int> numbers; // 字串裡抓到的所有數字
  final bool hasNegative;  // 是否有負數

  ParsedStringResult({
    required this.text,
    required this.numbers,
    required this.hasNegative,
  });
}
