package de.keplerchemnitz.kepler_app.widgets

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.Button
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.padding
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.Text
import de.keplerchemnitz.kepler_app.MainActivity
import java.util.Calendar
import androidx.core.content.edit
import androidx.glance.GlanceTheme
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.layout.Alignment
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.layout.wrapContentSize
import androidx.glance.text.FontStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class YourPlanWidget : GlanceAppWidget(errorUiLayout = de.keplerchemnitz.kepler_app.R.layout.your_plan_widget_error) {
    override val stateDefinition: GlanceStateDefinition<*>
        get() = HomeWidgetGlanceStateDefinition()
    @Composable fun themeStyle() = TextStyle(color = GlanceTheme.colors.onSurface)

    companion object {
        private val SMALL = DpSize(175.dp, 100.dp)
        private val BIGGER = DpSize(200.dp, 100.dp)
    }
    override val sizeMode = SizeMode.Responsive(setOf(
        SMALL,
        BIGGER
    ))
//    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context, currentState(), id)
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState, id: GlanceId) {
        val prefs = currentState.preferences
        val cal = Calendar.getInstance()
        // return, ohne etwas zu rendern, weil erst nach Konfiguration verfügbar
        val plan = prefs.getString("$id.selected_plan", null) ?: return
        if (!prefs.contains("$id.show_full_plan")) return
        val showFullPlan = prefs.getBoolean("$id.show_full_plan", true)

        val openSPPage = {
            prefs.edit(commit = true) { putString("start_page", "stuplan") }
            context.startActivity(Intent(context, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }

        Column(verticalAlignment = Alignment.CenterVertically, modifier = GlanceModifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                    .padding(16.dp).clickable(openSPPage).wrapContentSize().cornerRadius(16.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = GlanceModifier.wrapContentSize()
                ) {
                    if (cal.get(Calendar.DAY_OF_WEEK) == Calendar.SATURDAY || cal.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY) {
                        IconBar("Wochenende!")
                        Text(
                            "Heute ist keine Schule.",
                            style = TextStyle(
                                color = GlanceTheme.colors.onSurface,
                                textAlign = TextAlign.Center
                            )
                        )
                    } else {
                        val dataStr = prefs.getString("data", null)
                        val data = JSONObject(dataStr ?: "{}")
                        if (data.has("date") && data.getString("date") == "%02d-%02d-%04d".format(
                                cal.get(Calendar.DAY_OF_MONTH),
                                cal.get(Calendar.MONTH) + 1,
                                cal.get(Calendar.YEAR)
                            )
                        ) {
                            if (data.has("holiday") && data.getBoolean("holiday")) {
                                IconBar("Frei!")
                                Text(
                                    "Laut dem Stundenplan ist heute frei. In der App kann dies angepasst werden.",
                                    style = themeStyle()
                                )
                                Button("App öffnen", openSPPage)
                            } else {
                                IconBar(
                                    "Stundenplan am %02d.%02d.".format(
                                        cal.get(Calendar.DAY_OF_MONTH),
                                        cal.get(Calendar.MONTH) + 1
                                    )
                                )
                                Text(
                                    "für ${if (plan.contains("-")) "Klasse" else "Jahrgang"} $plan",
                                    style = TextStyle(
                                        fontStyle = FontStyle.Italic,
                                        fontSize = 12.sp
                                    )
                                )
                                val plans = data.getJSONObject("plans")
                                if (!plans.has(plan)) {
                                    Text("Fehler bei der Abfrage der Daten.", style = themeStyle())
                                } else {
                                    LessonList(
                                        plans.getJSONArray(plan).jsonObjectIterator().asSequence()
                                            .toList(), openSPPage, showFullPlan
                                    )
                                }
                            }
                        } else {
                            IconBar("Noch keine Daten verfügbar.")
                            Text(
                                "Bitte Kepler-App öffnen, um Stundenplan abzufragen.",
                                modifier = GlanceModifier.padding(bottom = 4.dp),
                                style = themeStyle()
                            )
                            Button("App öffnen", openSPPage)
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun IconBar(text: String) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(
                ImageProvider(de.keplerchemnitz.kepler_app.R.drawable.transparent_app_icon),
                "Kepler-App-Icon",
                modifier = GlanceModifier.padding(end = 8.dp).size(36.dp)
            )
            Text(
                text,
                modifier = GlanceModifier.padding(bottom = 4.dp),
                style = TextStyle(
                    fontSize = 16.sp,
                    color = GlanceTheme.colors.onSurface
                )
            )
        }
    }

    @Composable
    private fun LessonList(lessons: List<JSONObject>, openApp: () -> Unit, showFullPlan: Boolean) {
        val size = LocalSize.current
        val plan = if (showFullPlan) lessons else lessons.filter {
            val c = it.getJSONObject("changed")
            return@filter c.getBoolean("subject") || c.getBoolean("teacher") || c.getBoolean("rooms")
        }

        Spacer(GlanceModifier.height(4.dp))
        Box(GlanceModifier.background(GlanceTheme.colors.surfaceVariant).cornerRadius(8.dp).padding(4.dp)) {
            if (plan.isEmpty()) Text("Heute keine Vertretungen.")
            else LazyColumn(GlanceModifier.clickable(openApp).padding(2.dp)) {
                plan.forEachIndexed { i, it ->
                    val changed = it.getJSONObject("changed")
                    item(i.toLong()) {
                        Row(GlanceModifier.padding(2.dp).clickable(openApp)) {
                            Text(
                                if (i > 0 && plan[i - 1].getInt("schoolHour") == it.getInt("schoolHour")) "" else "${
                                    it.getInt(
                                        "schoolHour"
                                    )
                                }.",
                                style = themeStyle(),
                                modifier = GlanceModifier.padding(end = 4.dp, top = 2.dp).width(16.dp)
                            )
                            Column(modifier = GlanceModifier.padding(2.dp)) {
                                Row {
                                    Text(
                                        it.getString("subject"),
                                        style = TextStyle(
                                            color = if (changed.getBoolean("subject")) GlanceTheme.colors.error else GlanceTheme.colors.onSurface,
                                            fontWeight = FontWeight.Bold
                                        )
                                    )
                                    Text(
                                        it.getString("teacher"),
                                        modifier = GlanceModifier.padding(start = 4.dp),
                                        style = TextStyle(
                                            color = if (changed.getBoolean("teacher")) GlanceTheme.colors.error else GlanceTheme.colors.onSurface,
                                            fontStyle = FontStyle.Italic
                                        )
                                    )
                                }
                                if (it.has("info") && it.getString("info") != "") Text(
                                    if (size.width >= BIGGER.width) it.getString("info") else "Mehr Infos...",
                                    style = TextStyle(
                                        color = GlanceTheme.colors.onSurface,
                                        fontStyle = FontStyle.Italic
                                    )
                                )
                            }
                            if (size.width >= BIGGER.width) Row(
                                horizontalAlignment = Alignment.End,
                                modifier = GlanceModifier.fillMaxWidth()
                            ) {
                                Text(
                                    it.getJSONArray("rooms").stringIterator().asSequence()
                                        .joinToString(", "),
                                    style = TextStyle(
                                        color = if (changed.getBoolean("rooms")) GlanceTheme.colors.error else GlanceTheme.colors.onSurface,
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        val cal = Calendar.getInstance()
        provideContent {
            Box(
                modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground)
                    .padding(16.dp), Alignment.Center
            ) {
                Column(modifier = GlanceModifier.wrapContentSize()) {
                    IconBar("Stundenplan am %02d.%02d.".format(cal.get(Calendar.DAY_OF_MONTH), cal.get(Calendar.MONTH) + 1))
                    val size = LocalSize.current

                    Spacer(GlanceModifier.height(4.dp))
                    Box(GlanceModifier.background(GlanceTheme.colors.surfaceVariant).cornerRadius(8.dp).padding(4.dp)) {
                        Column(GlanceModifier.padding(2.dp)) {
                            (1 .. 3).forEach {
                                Row(GlanceModifier.padding(2.dp)) {
                                    Text(
                                        "$it.",
                                        style = themeStyle(),
                                        modifier = GlanceModifier.padding(end = 4.dp, top = 2.dp).width(16.dp)
                                    )
                                    Column(modifier = GlanceModifier.padding(2.dp)) {
                                        Row {
                                            Text(
                                                "Stunde $it",
                                                style = TextStyle(
                                                    color = if (it == 1) GlanceTheme.colors.error else GlanceTheme.colors.onSurface,
                                                    fontWeight = FontWeight.Bold
                                                )
                                            )
                                            Text(
                                                "Lehrer",
                                                modifier = GlanceModifier.padding(start = 4.dp),
                                                style = TextStyle(
                                                    color = if (it == 1) GlanceTheme.colors.error else GlanceTheme.colors.onSurface,
                                                    fontStyle = FontStyle.Italic
                                                )
                                            )
                                        }
                                    }
                                    if (size.width >= BIGGER.width) Row(
                                        horizontalAlignment = Alignment.End,
                                        modifier = GlanceModifier.fillMaxWidth()
                                    ) {
                                        Text(
                                            "30${10 - it}",
                                            style = TextStyle(
                                                color = if (it == 2) GlanceTheme.colors.error else GlanceTheme.colors.onSurface,
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override suspend fun onDelete(context: Context, glanceId: GlanceId) {
        HomeWidgetPlugin.getData(context).edit {
            remove("$glanceId.selected_plan")
            remove("$glanceId.full_plan")
        }
        super.onDelete(context, glanceId)
    }
}

fun JSONArray.jsonObjectIterator(): Iterator<JSONObject> {
    return object : Iterator<JSONObject> {
        var i = 0;
        override fun hasNext() = i < this@jsonObjectIterator.length()
        override fun next(): JSONObject {
            if (!hasNext()) throw NoSuchElementException()
            return this@jsonObjectIterator.getJSONObject(i++)
        }
    }
}

fun JSONArray.stringIterator(): Iterator<String> {
    return object : Iterator<String> {
        var i = 0;
        override fun hasNext() = i < this@stringIterator.length()
        override fun next(): String {
            if (!hasNext()) throw NoSuchElementException()
            return this@stringIterator.getString(i++)
        }
    }
}
