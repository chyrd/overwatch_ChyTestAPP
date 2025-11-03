import 'dart:async';
import 'dart:ffi';

import 'package:chyoverwatchapp/reactive_state.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'package:meta/meta.dart';

class BleScanner implements ReactiveState<BleScannerState> {
  BleScanner({required FlutterReactiveBle ble}) : _ble = ble;

  final FlutterReactiveBle _ble;
  final StreamController<BleScannerState> _stateStreamController =
      StreamController();

  final _devices = <DiscoveredDevice>[];

  int isDevStreamErr = 1; // 0 可用的, 1 啟動,尚未搜尋到資料, 99 error, 98 done
  bool devNameFilter = false;//true ： BLE

  late List<String> deviceidFilter;

  void setFilter(String conn,List<String> device){
    deviceidFilter = device;
    _devices.clear();
  }


  late Timer blescanlooptimer = Timer.periodic(const Duration(seconds: 30), (timer) {
    //BLE Scan有時間限制，但 scanForDevices 不會被停止，Done等事件也不被觸發，使用者需要自行處理結束問題，
    //設定5分鐘重啟一次 Scan stream

    _subscription?.cancel();
    _subscription = null;
    //blescanlooptimer.cancel();
    startScan([]);
    isDevStreamErr=1;

  });

  @override
  Stream<BleScannerState> get state => _stateStreamController.stream;

  void startScan(List<Uuid> serviceIds) {
    _devices.clear();
    _subscription?.cancel();
    isDevStreamErr = 1;
    _pushState();/// isDevStreamErr =1時更新一下狀態


    _subscription = _ble
        .scanForDevices(withServices: serviceIds, scanMode: ScanMode.lowLatency)
    .timeout( Duration(seconds: 10),
      onTimeout: (DiscoveredDevice){
      //timeout 後重新啟動 scan
        startScan([]);
        print("scanForDevices timeout then app do restart");
      })
        .listen((device) {
      isDevStreamErr = 0;
            if(devNameFilter){

                final knownDeviceIndex = _devices.indexWhere((d) => d.id == device.id);
                if (knownDeviceIndex >= 0) {
                  _devices[knownDeviceIndex] = device;
                } else {
                  if(double.tryParse(device.name.substring(3,8))!=null){///要有TM 及判斷中間為日期
                    _devices.add(device);
                    print("ble add ${device.name} , ${device.id}");

                  }

                }
                _pushState();

            }else{//沒有過濾就全部顯示
              print("beaccon manufacturerData.length${device.id} : ${device.manufacturerData.length}");

              final knownDeviceIndex = _devices.indexWhere((d) => d.id == device.id);
              if (knownDeviceIndex >= 0) {
                _devices[knownDeviceIndex] = device;
              } else {
                _devices.add(device);
              }
              _pushState();
            }


    }
    , onError: (Object e) =>  {

    isDevStreamErr = 99,
      _devices.clear(),
    _subscription?.cancel(),
    print('BLE Scan error:${e.toString()}'),
        _pushState()
 },
    onDone: (){
          isDevStreamErr = 98;
          _devices.clear();
          _subscription?.cancel();
      print('Ble done');
          _pushState();
      },cancelOnError: true
    );

    _pushState();
  }

  void _pushState() {
    _stateStreamController.add(
      BleScannerState(
        discoveredDevices: _devices,
        scanIsInProgress: _subscription != null,
        scanIsPause: isDevStreamErr,
      ),
    );
  }

  Future<void> stopScan()  async {
     await _subscription?.cancel();
     _subscription = null;
     blescanlooptimer.cancel();
     _pushState();
    print("stopscan");
  }

  Future<void> dispose() async {
    await _stateStreamController.close();
    // await _CHY_PacketStreamController.close();

  }

  StreamSubscription? _subscription;
}

@immutable
class BleScannerState {
   const BleScannerState({
    required this.discoveredDevices,
    required this.scanIsInProgress,
    required this.scanIsPause,
  });

  final List<DiscoveredDevice> discoveredDevices;
  final bool scanIsInProgress;
  final int scanIsPause;
}

