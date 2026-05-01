package com.aadishsamir.weatherfast

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.NumberPicker
import android.widget.TextView

class WeatherWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_weather_widget_configure)

        val appWidgetManager = AppWidgetManager.getInstance(this)
        val providerInfo = appWidgetManager.getAppWidgetInfo(appWidgetId)
        val widgetFamily = resolveWidgetFamily(providerInfo?.provider)

        val titleView = findViewById<TextView>(R.id.widget_config_title)
        val hourlyPicker = findViewById<NumberPicker>(R.id.widget_config_hourly_picker)
        val dailySection = findViewById<View>(R.id.widget_config_daily_section)
        val dailyPicker = findViewById<NumberPicker>(R.id.widget_config_daily_picker)
        val transparentSwitch = findViewById<android.widget.Switch>(R.id.widget_config_transparent_switch)
        val colorGroup = findViewById<android.widget.RadioGroup>(R.id.widget_config_text_color_group)
        val colorWhite = findViewById<android.widget.RadioButton>(R.id.widget_config_text_white)
        val colorBlack = findViewById<android.widget.RadioButton>(R.id.widget_config_text_black)
        val customColorSection = findViewById<View>(R.id.widget_config_custom_color_section)
        val customColorInput = findViewById<android.widget.EditText>(R.id.widget_config_custom_color_input)
        val cancelButton = findViewById<Button>(R.id.widget_config_cancel)
        val saveButton = findViewById<Button>(R.id.widget_config_save)

        titleView.text = when (widgetFamily) {
            "small" -> "Configure Small Widget"
            "medium" -> "Configure Medium Widget"
            else -> "Configure Large Widget"
        }

        val existing = WeatherWidgetConfigStore.load(this, appWidgetId)

        hourlyPicker.minValue = 0
        hourlyPicker.maxValue = 24
        hourlyPicker.wrapSelectorWheel = false
        hourlyPicker.value = (existing.hourlyCards ?: defaultHourlyCards(widgetFamily)).coerceIn(0, 24)
        
        transparentSwitch.isChecked = existing.isTransparent
        if (existing.isTextBlack) {
            colorBlack.isChecked = true
        } else {
            colorWhite.isChecked = true
        }
        
        customColorSection.visibility = if (existing.isTransparent) View.VISIBLE else View.GONE
        customColorInput.setText(existing.customThemeColor ?: "")

        transparentSwitch.setOnCheckedChangeListener { _, isChecked ->
            customColorSection.visibility = if (isChecked) View.VISIBLE else View.GONE
        }

        if (widgetFamily == "large") {
            dailySection.visibility = View.VISIBLE
            dailyPicker.minValue = 0
            dailyPicker.maxValue = 7
            dailyPicker.wrapSelectorWheel = false
            dailyPicker.value = (existing.dailyCards ?: 4).coerceIn(0, 7)
        } else {
            dailySection.visibility = View.GONE
            dailyPicker.value = 0
        }

        cancelButton.setOnClickListener {
            finish()
        }

        saveButton.setOnClickListener {
            val hourlyCards = hourlyPicker.value
            val dailyCards = if (widgetFamily == "large") dailyPicker.value else 0
            val isTransparent = transparentSwitch.isChecked
            val isTextBlack = colorBlack.isChecked
            val customThemeColor = customColorInput.text.toString().takeIf { isTransparent && it.isNotBlank() }
            WeatherWidgetConfigStore.save(this, appWidgetId, hourlyCards, dailyCards, isTransparent, isTextBlack, customThemeColor)

            requestWidgetUpdate(providerInfo?.provider)

            val result = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(RESULT_OK, result)
            finish()
        }
    }

    private fun resolveWidgetFamily(provider: ComponentName?): String {
        val className = provider?.className ?: return "large"
        return when {
            className.contains("Small", ignoreCase = true) -> "small"
            className.contains("Medium", ignoreCase = true) -> "medium"
            else -> "large"
        }
    }

    private fun defaultHourlyCards(widgetFamily: String): Int {
        return when (widgetFamily) {
            "small" -> 4
            else -> 6
        }
    }

    private fun requestWidgetUpdate(provider: ComponentName?) {
        if (provider == null) {
            return
        }

        val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
            component = provider
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        sendBroadcast(updateIntent)
    }
}
