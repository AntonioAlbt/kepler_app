package de.keplerchemnitz.kepler_app

import android.os.Build
import android.os.Bundle
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.setWidgetPreviews
import de.keplerchemnitz.kepler_app.widgets.YourPlanWidgetReceiver
import io.flutter.embedding.android.FlutterActivity
import kotlinx.coroutines.runBlocking

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            runBlocking {
                GlanceAppWidgetManager(this@MainActivity).setWidgetPreviews<YourPlanWidgetReceiver>()
            }
        }
    }
}
