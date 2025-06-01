package de.keplerchemnitz.kepler_app.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.ArrayAdapter
import android.widget.CheckBox
import android.widget.Spinner
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import de.keplerchemnitz.kepler_app.R
import es.antonborri.home_widget.HomeWidgetPlugin
import androidx.core.content.edit
import androidx.glance.appwidget.GlanceAppWidgetManager
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class YourPlanWidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val prefs = HomeWidgetPlugin.getData(this);
        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_CANCELED, resultValue)

        if (!prefs.getBoolean("plan_setup", false)) {
            setResult(RESULT_CANCELED)
            MaterialAlertDialogBuilder(this)
                .setTitle("Noch nicht eingerichtet")
                .setMessage("Der Stundenplan muss für die Verwendung dieses Widgets erst eingerichtet werden.\nFalls dieser schon eingerichtet wurde, bitte die App neu starten.")
                .setNegativeButton("Schließen") { _, _ -> }
                .setOnDismissListener { finish() }
                .show()
        } else {
            val dialog = layoutInflater.inflate(R.layout.your_plan_widget_config_dialog, null)
            val spinner = dialog.findViewById<Spinner>(R.id.yp_config_plan_selector)
            spinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, prefs.getString("plans_avail", null)!!.split("|"))
            val checkbox = dialog.findViewById<CheckBox>(R.id.yp_config_checkbox)
            MaterialAlertDialogBuilder(this)
                .setTitle("Stundenplan auswählen")
                .setView(dialog)
                .setPositiveButton("Jetzt platzieren") { _, _ ->
                    val gid = GlanceAppWidgetManager(this).getGlanceIdBy(appWidgetId)
                    prefs.edit {
                        putString("$gid.selected_plan", spinner.selectedItem.toString())
                        putBoolean("$gid.show_full_plan", !checkbox.isChecked)
                    }
                    Log.d(null, "set $gid.selected_plan -> ${prefs.getString("$gid.selected_plan", null)}")
                    setResult(RESULT_OK)
                    runBlocking {
                        launch { YourPlanWidget().update(this@YourPlanWidgetConfigActivity, gid) }
                    }
                    finish()
                }
                .setNegativeButton("Abbrechen") { _, _ -> setResult(RESULT_CANCELED) }
                .show()
        }
    }
}