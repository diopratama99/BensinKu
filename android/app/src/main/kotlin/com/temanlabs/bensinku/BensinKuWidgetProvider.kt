package com.temanlabs.bensinku

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * BensinKu home widget provider (4x2).
 *
 * Renders the editorial cream/butter widget. Pulls dynamic content
 * (greeting, footer stats) from the SharedPreferences populated by the
 * `home_widget` Flutter plugin via `HomeWidget.saveWidgetData(...)`.
 *
 * Click intents:
 *   - Tombol "MULAI PERJALANAN" → launch MainActivity dengan deeplink
 *     `bensinku://widget/start-trip`. MainActivity baca uri-nya lalu
 *     ekspos ke Flutter side via method channel.
 *   - Tap selain tombol → buka aplikasi normal di tab terakhir.
 */
class BensinKuWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.bensinku_widget)

            val greeting = widgetData.getString("widget_greeting", null)
                ?: "Selamat datang"
            val date = widgetData.getString("widget_date", null) ?: ""
            val footer = widgetData.getString("widget_footer", null)
                ?: "Belum ada catatan bulan ini"

            views.setTextViewText(R.id.widget_greeting, greeting)
            views.setTextViewText(R.id.widget_date, date)
            views.setTextViewText(R.id.widget_footer, footer)

            // Tap pada body widget → buka app biasa.
            val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent)

            // Tap tombol MULAI → buka app dengan deeplink khusus.
            val startTripIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("bensinku://widget/start-trip"),
            )
            views.setOnClickPendingIntent(R.id.widget_start_button, startTripIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    companion object {
        /** Helper untuk Flutter side memicu update semua instance widget. */
        fun forceUpdateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, BensinKuWidgetProvider::class.java)
            val ids = mgr.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            val intent = Intent(context, BensinKuWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
