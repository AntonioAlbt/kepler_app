package de.keplerchemnitz.kepler_app.widgets

import android.app.Activity
import android.content.DialogInterface
import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.CheckBox
import android.widget.Spinner
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import de.keplerchemnitz.kepler_app.MainActivity
import de.keplerchemnitz.kepler_app.R
import es.antonborri.home_widget.HomeWidgetPlugin
import androidx.core.content.edit

class YourPlanWidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val prefs = HomeWidgetPlugin.getData(this);

        if (!prefs.getBoolean("plan_setup", false)) {
            setResult(RESULT_CANCELED)
            MaterialAlertDialogBuilder(this)
                .setTitle("Noch nicht eingerichtet")
                .setMessage("Der Stundenplan muss für die Verwendung dieses Widgets erst eingerichtet werden.")
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
                    prefs.edit {
                        putString("selected_plan", spinner.selectedItem.toString())
                        putBoolean("show_full_plan", !checkbox.isChecked)
                    }
                    setResult(RESULT_OK)
                }
                .setNegativeButton("Abbrechen") { _, _ -> setResult(RESULT_CANCELED) }
                .setOnDismissListener { finish() }
                .show()
        }
    }
}