package com.example.chyoverwatchapp

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins
import android.util.Log
class MainActivity: FlutterActivity() {

    private val channelName = "bondStateChannel"
    private lateinit var channel: MethodChannel
    private var bondReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)

        registerBondReceiver()
        RxJavaPlugins.setErrorHandler { e ->
            Log.w("RxJava", "UndeliverableException suppressed: $e")
        }
    }
//    @RequiresApi(Build.VERSION_CODES.O)
//    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
//        RxJavaPlugins.setErrorHandler { e ->
//            Log.w("RxJava", "UndeliverableException suppressed: $e")
//        }
//    }
    private fun registerBondReceiver() {
        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)

        bondReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {

                    val device =
                        intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                    val state =
                        intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)

                    val deviceId = device?.address ?: return

                    channel.invokeMethod(
                        "bondStateChanged",
                        mapOf("deviceId" to deviceId, "state" to state)
                    )
                }
            }
        }

        registerReceiver(bondReceiver, filter)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (bondReceiver != null) {
            unregisterReceiver(bondReceiver)
        }
    }
}
