package com.temanlabs.bensinku

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "bensinku/widget_intent"
    private var pendingTripStart: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingTripStart = isStartTripIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (isStartTripIntent(intent)) {
            pendingTripStart = true
        }
        setIntent(intent)
    }

    /**
     * Detect deeplink fired by the home widget. The widget Provider
     * uses `HomeWidgetLaunchIntent.getActivity(... Uri ...)` which
     * sets `intent.data` to `bensinku://widget/start-trip`.
     *
     * For backward compat we also still accept the old boolean extra
     * `start_trip_immediately=true` in case some external caller wants
     * to use it.
     */
    private fun isStartTripIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        val data = intent.data
        if (data != null && data.scheme == "bensinku" &&
            data.host == "widget" &&
            data.path == "/start-trip"
        ) {
            return true
        }
        return intent.getBooleanExtra("start_trip_immediately", false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingTripStart" -> {
                    val v = pendingTripStart
                    pendingTripStart = false
                    result.success(v)
                }
                else -> result.notImplemented()
            }
        }
    }
}
