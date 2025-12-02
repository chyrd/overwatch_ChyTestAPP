import 'dart:async';
import 'package:flutter/services.dart';

enum BondState {
  none,
  bonding,
  bonded,
}

class BondingService {
  static const MethodChannel _channel = MethodChannel("bondStateChannel");

  final _controller = StreamController<Map<String, BondState>>.broadcast();

  BondingService() {
    _channel.setMethodCallHandler(_handleCall);
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method == "bondStateChanged") {
      final deviceId = call.arguments["deviceId"];
      final stateInt = call.arguments["state"];

      final state = _mapBondState(stateInt);
      _controller.add({deviceId: state});
    }
  }

  BondState _mapBondState(int value) {
    switch (value) {
      case 10:
        return BondState.none;
      case 11:
        return BondState.bonding;
      case 12:
        return BondState.bonded;
      default:
        return BondState.none;
    }
  }

  /// 取得某個 deviceId 的 Bonding Stream
  Stream<BondState> bondStateStream(String deviceId) {
    return _controller.stream
        .where((event) => event.keys.contains(deviceId))
        .map((event) => event[deviceId]!);
  }
  // Future<void> cleanupBle() async {
  //   try {
  //     await _controller!.cancel();
  //   } catch (_) {}
  //
  //   try {
  //     await _notifySub?.cancel();
  //   } catch (_) {}
  //
  //   _connectionSub = null;
  //   _notifySub = null;
  // }
}



final bondingService = BondingService();
