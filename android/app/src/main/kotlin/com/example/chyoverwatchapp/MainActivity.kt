package com.example.chyoverwatchapp

import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import com.polidea.rxandroidble2.exceptions.BleException

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(mainPlugin())
    }

}
class mainPlugin:FlutterPlugin{
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    }
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {

        RxJavaPlugins.setErrorHandler { throwable ->
            if (throwable is UndeliverableException && throwable.cause is BleException) {
                return@setErrorHandler // ignore BleExceptions since we do not have subscriber
            } else {
                throw throwable
            }
        }


    }
}
