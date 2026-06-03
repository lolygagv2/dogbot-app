package com.wimzai.app

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * WIM-Z host activity.
 *
 * Adds a "wifi_bind" platform channel so Dart can pin the whole process to the
 * WiFi transport while in local-AP mode. When the phone joins the WIMZ- access
 * point (which has no upstream internet), Android's connectivity logic detects
 * the dead end and may route app sockets back over cellular — so REST/WS/MJPEG
 * to the robot silently never arrive. bindProcessToNetwork() forces every
 * socket in this process onto the WiFi network until we unbind. iOS has no
 * equivalent problem, so the Dart side no-ops there.
 */
class MainActivity : FlutterActivity() {
    private val wifiChannelName = "com.wimzai.app/wifi_bind"
    private val foregroundChannelName = "com.wimzai.app/foreground"
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        connectivityManager =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bindToWifi" -> bindToWifi(result)
                    "unbind" -> {
                        unbind()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, foregroundChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startSessionService()
                        result.success(true)
                    }
                    "stop" -> {
                        stopSessionService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startSessionService() {
        val intent = Intent(this, WimzForegroundService::class.java).apply {
            action = WimzForegroundService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopSessionService() {
        val intent = Intent(this, WimzForegroundService::class.java).apply {
            action = WimzForegroundService.ACTION_STOP
        }
        startService(intent)
    }

    private fun bindToWifi(result: MethodChannel.Result) {
        val cm = connectivityManager
        if (cm == null) {
            result.success(false)
            return
        }
        // Drop any prior binding/callback before requesting a fresh one.
        unbind()

        // Require WiFi transport but NOT internet capability — the robot AP has
        // no upstream, so demanding NET_CAPABILITY_INTERNET would never match.
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()

        var settled = false
        val timeout = Runnable {
            if (!settled) {
                settled = true
                unbind()
                result.success(false)
            }
        }

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                mainHandler.post {
                    mainHandler.removeCallbacks(timeout)
                    if (settled) return@post
                    settled = true
                    val ok = try {
                        cm.bindProcessToNetwork(network)
                    } catch (e: Exception) {
                        false
                    }
                    result.success(ok)
                }
            }

            override fun onUnavailable() {
                mainHandler.post {
                    mainHandler.removeCallbacks(timeout)
                    if (settled) return@post
                    settled = true
                    result.success(false)
                }
            }
        }
        networkCallback = callback

        try {
            cm.requestNetwork(request, callback)
            // Safety net: if neither callback fires (e.g. WiFi off), settle false.
            mainHandler.postDelayed(timeout, 8000)
        } catch (e: Exception) {
            networkCallback = null
            if (!settled) {
                settled = true
                result.success(false)
            }
        }
    }

    private fun unbind() {
        val cm = connectivityManager ?: return
        try {
            cm.bindProcessToNetwork(null)
        } catch (e: Exception) {
            // ignore — nothing was bound
        }
        networkCallback?.let {
            try {
                cm.unregisterNetworkCallback(it)
            } catch (e: Exception) {
                // ignore — callback already gone
            }
        }
        networkCallback = null
    }

    override fun onDestroy() {
        unbind()
        super.onDestroy()
    }
}
