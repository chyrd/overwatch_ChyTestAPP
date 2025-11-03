import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../reactive_state.dart';
import 'ble_UUID.dart';

class BleDeviceConnector extends ReactiveState<ConnectionStateUpdate> {
  BleDeviceConnector({
    required FlutterReactiveBle ble,
  })  : _ble = ble;

  final FlutterReactiveBle _ble;


  @override
  Stream<ConnectionStateUpdate> get state => _deviceConnectionController.stream;

  final _deviceConnectionController = StreamController<ConnectionStateUpdate>();

  // ignore: cancel_subscriptions
  late StreamSubscription<ConnectionStateUpdate> _connection;
  late QualifiedCharacteristic writecharacteristic, readcharacteristic;
  late Stream<List<int>> readBuffStream;
  Future<void> connect(String deviceId) async {

    // _ble.connectedDeviceStream
    // await _ble.connectToDevice(id: deviceId).first;
    // await Future.delayed(Duration(seconds: 1));
    // final services = await ble.discoverServices(deviceId);
    // _connection.isPaused;
    // _connection.cancel();

    _connection = _ble.connectToDevice(id: deviceId,servicesWithCharacteristicsToDiscover:
    {Uuid.parse(CLIENT_CHARACTERISTIC_SERVICE_UUID):
    [Uuid.parse(READ_CLIENT_CHARACTERISTIC_CONNECT_UUID),
      Uuid.parse(SEND_CLIENT_CHARACTERISTIC_CONNECT_UUID)]},
      connectionTimeout: const Duration(seconds: 15),).listen (
            (update) async{
          /// 連線後直接訂閱RX的UUID， meter TX/RX UUID都一樣
          if (update.connectionState == DeviceConnectionState.connected) {

            // await _ble.requestConnectionPriority(
            //   deviceId: deviceId,
            //   priority: ConnectionPriority.balanced,//預設已經是平衡狀態
            // );
            try {
              _ble.discoverAllServices(deviceId);
            } on PlatformException catch (e) {
              print("Failed to call platform method: '${e.message}'");
            }catch (c){
              print("_ble.discoverAllServices err: '${c.toString()}'");
            }

            readcharacteristic = QualifiedCharacteristic(
                characteristicId: Uuid.parse(READ_CLIENT_CHARACTERISTIC_CONNECT_UUID),
                serviceId: Uuid.parse(CLIENT_CHARACTERISTIC_SERVICE_UUID),
                deviceId: deviceId.toString());
            writecharacteristic = QualifiedCharacteristic(
                characteristicId: Uuid.parse(SEND_CLIENT_CHARACTERISTIC_CONNECT_UUID),
                serviceId: Uuid.parse(CLIENT_CHARACTERISTIC_SERVICE_UUID),
                deviceId: deviceId.toString());
            readBuffStream = _ble.subscribeToCharacteristic(readcharacteristic).asBroadcastStream();
            //print("get uuid $writecharacteristic");
            // _deviceConnectionController.add(update);
          }else if (update.connectionState == DeviceConnectionState.disconnected) {
            // _deviceConnectionController.add(update);
          }
          _deviceConnectionController.add(update);
        },
        onError: (Object e) =>
        { print("connect onError: '${e.toString()}'")}
    );
  }

  Future<void> disconnect(String deviceId) async {
    try {
      //_logMessage('disconnecting to device: $deviceId');
      await _connection.cancel();

    } on Exception catch (e, _) {
      // _logMessage("Error disconnecting from a device: $e");
    } finally {
      // Since [_connection] subscription is terminated, the "disconnected" state cannot be received and propagated
      _deviceConnectionController.add(
        ConnectionStateUpdate(
          deviceId: deviceId,
          connectionState: DeviceConnectionState.disconnected,
          failure: null,
        ),
      );
    }
  }

  Future<void> dispose() async {
    await _deviceConnectionController.close();
  }
  Future<int> getRssi(rssi)  {
    return  _ble.readRssi(rssi);
  }
  Future<int> setMtu(id,val)  async {
    final mtu = await _ble.requestMtu(deviceId: id, mtu: val);
    return  mtu;
  }
  Future<void> clearGattCache(deviceId)  async {
    if(Platform.isAndroid){///連線前先清除gatt
      _ble.clearGattCache(deviceId);
    }
  }


}
