package com.aadishsamir.weatherfast

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.min

abstract class WeatherFastWidgetProviderBase(
    private val widgetFamily: String,
) : HomeWidgetProvider() {
    private data class WidgetSizeProfile(
        val hourlyCardsVisible: Int,
        val dailyCardsVisible: Int,
        val headingSize: Float,
        val subHeadingSize: Float,
        val tempSize: Float,
        val hourlyTimeSize: Float,
        val hourlyTempSize: Float,
        val hourlyConditionSize: Float,
        val dailyNameSize: Float,
        val dailyTempSize: Float,
        val isTransparent: Boolean,
        val isTextBlack: Boolean,
        val customThemeColor: String?,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            updateWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        updateWidget(context, appWidgetManager, appWidgetId, prefs)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.weather_widget_host)
        val widgetOptions = appWidgetManager.getAppWidgetOptions(widgetId)
        val profile = resolveSizeProfile(context, widgetId, widgetOptions)

        bindData(context, views, widgetData)
        applySizeLayout(context, views, profile)
        applyResponsiveTextSizes(context, views, profile)
        applyAppearance(context, views, profile)

        views.setOnClickPendingIntent(
            R.id.widget_root,
            WeatherWidgetCommon.openAppIntent(context, 1000 + widgetId),
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun applyAppearance(context: Context, views: RemoteViews, profile: WidgetSizeProfile) {
        if (profile.isTransparent) {
            views.setInt(R.id.widget_root, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_hourly_strip, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_hourly_strip_2, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_hourly_strip_3, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_hourly_strip_4, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_day_card_1, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_day_card_2, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_day_card_3, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_day_card_4, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_day_card_5, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_day_card_6, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
            views.setInt(R.id.widget_day_card_7, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
        } else {
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.weather_widget_gradient_background)
            views.setInt(R.id.widget_hourly_strip, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_hourly_strip_2, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_hourly_strip_3, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_hourly_strip_4, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_day_card_1, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_day_card_2, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_day_card_3, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_day_card_4, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_day_card_5, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_day_card_6, "setBackgroundResource", R.drawable.weather_widget_card_bg)
            views.setInt(R.id.widget_day_card_7, "setBackgroundResource", R.drawable.weather_widget_card_bg)
        }

        val brightColor: Int
        val dimColor: Int
        val hourlyTempColor: Int
        
        var customBright: Int? = null
        var customDim: Int? = null
        if (profile.isTransparent && !profile.customThemeColor.isNullOrBlank()) {
            try {
                var colorStr = profile.customThemeColor
                if (!colorStr.startsWith("#")) colorStr = "#$colorStr"
                val parsedColor = android.graphics.Color.parseColor(colorStr)
                customBright = parsedColor
                // Dim the custom color a little for the dimColor (reduce alpha)
                customDim = android.graphics.Color.argb(
                    200, // ~78% opacity
                    android.graphics.Color.red(parsedColor),
                    android.graphics.Color.green(parsedColor),
                    android.graphics.Color.blue(parsedColor)
                )
            } catch (e: Exception) {
                // Ignore parse errors, fallback to default
            }
        }
        
        if (customBright != null && customDim != null) {
            brightColor = customBright
            hourlyTempColor = customBright
            dimColor = customDim
        } else {
            brightColor = if (profile.isTextBlack) android.graphics.Color.BLACK else android.graphics.Color.parseColor("#F4FAFF")
            dimColor = if (profile.isTextBlack) android.graphics.Color.parseColor("#444444") else android.graphics.Color.parseColor("#CADAEA")
            hourlyTempColor = if (profile.isTextBlack) android.graphics.Color.BLACK else android.graphics.Color.parseColor("#EAF3FB")
        }

        views.setTextColor(R.id.widget_location, brightColor)
        views.setTextColor(R.id.widget_condition, dimColor)
        views.setTextColor(R.id.widget_temp, brightColor)
        views.setTextColor(R.id.widget_high_low, dimColor)

        views.setTextColor(R.id.widget_hourly_title, brightColor)
        views.setTextColor(R.id.widget_daily_title, brightColor)

        for (index in 1..24) {
            val timeId = context.resources.getIdentifier("widget_hour_time_$index", "id", context.packageName)
            if (timeId != 0) views.setTextColor(timeId, dimColor)

            val tempId = context.resources.getIdentifier("widget_hour_temp_$index", "id", context.packageName)
            if (tempId != 0) views.setTextColor(tempId, hourlyTempColor)

            val conditionId = context.resources.getIdentifier("widget_hour_condition_$index", "id", context.packageName)
            if (conditionId != 0) views.setTextColor(conditionId, dimColor)
        }

        views.setTextColor(R.id.widget_day_name_1, brightColor)
        views.setTextColor(R.id.widget_day_name_2, brightColor)
        views.setTextColor(R.id.widget_day_name_3, brightColor)
        views.setTextColor(R.id.widget_day_name_4, brightColor)
        views.setTextColor(R.id.widget_day_name_5, brightColor)
        views.setTextColor(R.id.widget_day_name_6, brightColor)
        views.setTextColor(R.id.widget_day_name_7, brightColor)

        views.setTextColor(R.id.widget_day_temp_1, hourlyTempColor)
        views.setTextColor(R.id.widget_day_temp_2, hourlyTempColor)
        views.setTextColor(R.id.widget_day_temp_3, hourlyTempColor)
        views.setTextColor(R.id.widget_day_temp_4, hourlyTempColor)
        views.setTextColor(R.id.widget_day_temp_5, hourlyTempColor)
        views.setTextColor(R.id.widget_day_temp_6, hourlyTempColor)
        views.setTextColor(R.id.widget_day_temp_7, hourlyTempColor)
    }

    private fun applySizeLayout(context: Context, views: RemoteViews, profile: WidgetSizeProfile) {
        for (index in 1..24) {
            val cardId = context.resources.getIdentifier(
                "widget_hour_card_$index",
                "id",
                context.packageName,
            )
            if (cardId != 0) {
                views.setViewVisibility(cardId, if (profile.hourlyCardsVisible >= index) View.VISIBLE else View.GONE)
            }
        }
        views.setViewVisibility(
            R.id.widget_hourly_strip,
            if (profile.hourlyCardsVisible > 0) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_hourly_strip_2,
            if (profile.hourlyCardsVisible > 6) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_hourly_strip_3,
            if (profile.hourlyCardsVisible > 12) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_hourly_strip_4,
            if (profile.hourlyCardsVisible > 18) View.VISIBLE else View.GONE,
        )

        val showDaily = profile.dailyCardsVisible > 0
        views.setViewVisibility(R.id.widget_section_daily, if (showDaily) View.VISIBLE else View.GONE)
        views.setViewVisibility(
            R.id.widget_day_card_1,
            if (profile.dailyCardsVisible >= 1) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_day_card_2,
            if (profile.dailyCardsVisible >= 2) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_day_card_3,
            if (profile.dailyCardsVisible >= 3) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_day_card_4,
            if (profile.dailyCardsVisible >= 4) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_day_card_5,
            if (profile.dailyCardsVisible >= 5) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_day_card_6,
            if (profile.dailyCardsVisible >= 6) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.widget_day_card_7,
            if (profile.dailyCardsVisible >= 7) View.VISIBLE else View.GONE,
        )
    }

    private fun applyResponsiveTextSizes(context: Context, views: RemoteViews, profile: WidgetSizeProfile) {
        val headingSize = profile.headingSize
        val subHeadingSize = profile.subHeadingSize
        val tempSize = profile.tempSize
        val hourlyTimeSize = profile.hourlyTimeSize
        val hourlyTempSize = profile.hourlyTempSize
        val hourlyConditionSize = profile.hourlyConditionSize
        val dailyNameSize = profile.dailyNameSize
        val dailyTempSize = profile.dailyTempSize

        // Header
        views.setTextViewTextSize(R.id.widget_location, android.util.TypedValue.COMPLEX_UNIT_SP, headingSize)
        views.setTextViewTextSize(R.id.widget_condition, android.util.TypedValue.COMPLEX_UNIT_SP, subHeadingSize - 1)
        views.setTextViewTextSize(R.id.widget_temp, android.util.TypedValue.COMPLEX_UNIT_SP, tempSize)
        views.setTextViewTextSize(R.id.widget_high_low, android.util.TypedValue.COMPLEX_UNIT_SP, subHeadingSize - 2)

        // Hourly
        for (index in 1..24) {
            val timeId = context.resources.getIdentifier(
                "widget_hour_time_$index",
                "id",
                context.packageName,
            )
            if (timeId != 0) {
                views.setTextViewTextSize(timeId, android.util.TypedValue.COMPLEX_UNIT_SP, hourlyTimeSize)
            }

            val tempId = context.resources.getIdentifier(
                "widget_hour_temp_$index",
                "id",
                context.packageName,
            )
            if (tempId != 0) {
                views.setTextViewTextSize(tempId, android.util.TypedValue.COMPLEX_UNIT_SP, hourlyTempSize)
            }

            val conditionId = context.resources.getIdentifier(
                "widget_hour_condition_$index",
                "id",
                context.packageName,
            )
            if (conditionId != 0) {
                views.setTextViewTextSize(conditionId, android.util.TypedValue.COMPLEX_UNIT_SP, hourlyConditionSize)
            }
        }

        // Daily
        views.setTextViewTextSize(R.id.widget_day_name_1, android.util.TypedValue.COMPLEX_UNIT_SP, dailyNameSize)
        views.setTextViewTextSize(R.id.widget_day_name_2, android.util.TypedValue.COMPLEX_UNIT_SP, dailyNameSize)
        views.setTextViewTextSize(R.id.widget_day_name_3, android.util.TypedValue.COMPLEX_UNIT_SP, dailyNameSize)
        views.setTextViewTextSize(R.id.widget_day_name_4, android.util.TypedValue.COMPLEX_UNIT_SP, dailyNameSize)
        views.setTextViewTextSize(R.id.widget_day_name_5, android.util.TypedValue.COMPLEX_UNIT_SP, dailyNameSize)
        views.setTextViewTextSize(R.id.widget_day_name_6, android.util.TypedValue.COMPLEX_UNIT_SP, dailyNameSize)
        views.setTextViewTextSize(R.id.widget_day_name_7, android.util.TypedValue.COMPLEX_UNIT_SP, dailyNameSize)

        views.setTextViewTextSize(R.id.widget_day_temp_1, android.util.TypedValue.COMPLEX_UNIT_SP, dailyTempSize)
        views.setTextViewTextSize(R.id.widget_day_temp_2, android.util.TypedValue.COMPLEX_UNIT_SP, dailyTempSize)
        views.setTextViewTextSize(R.id.widget_day_temp_3, android.util.TypedValue.COMPLEX_UNIT_SP, dailyTempSize)
        views.setTextViewTextSize(R.id.widget_day_temp_4, android.util.TypedValue.COMPLEX_UNIT_SP, dailyTempSize)
        views.setTextViewTextSize(R.id.widget_day_temp_5, android.util.TypedValue.COMPLEX_UNIT_SP, dailyTempSize)
        views.setTextViewTextSize(R.id.widget_day_temp_6, android.util.TypedValue.COMPLEX_UNIT_SP, dailyTempSize)
        views.setTextViewTextSize(R.id.widget_day_temp_7, android.util.TypedValue.COMPLEX_UNIT_SP, dailyTempSize)
    }

    private fun resolveSizeProfile(
        context: Context,
        widgetId: Int,
        widgetOptions: Bundle,
    ): WidgetSizeProfile {
        val minWidthDp = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            .takeIf { it > 0 }
            ?: defaultMinWidthDp()
        val minHeightDp = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            .takeIf { it > 0 }
            ?: defaultMinHeightDp()
        val maxHeightDp = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            .takeIf { it > 0 }
            ?: minHeightDp
        val maxWidthDp = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
            .takeIf { it > 0 }
            ?: minWidthDp
        val effectiveWidthDp = maxOf(minWidthDp, maxWidthDp)
        val effectiveHeightDp = maxOf(minHeightDp, maxHeightDp)
        val widgetSettings = WeatherWidgetConfigStore.load(context, widgetId)
        val hourlyCardsVisible = widgetSettings.hourlyCards?.coerceIn(0, 24) ?: defaultHourlyCardsVisible(effectiveWidthDp)
        val dailyCardsVisible = when (widgetFamily) {
            "large" -> {
                val dailyUserCap = widgetSettings.dailyCards?.coerceIn(0, 7) ?: 4
                min(resolveDailyCardsVisible(effectiveHeightDp), dailyUserCap)
            }
            else -> 0
        }
        val isTransparent = widgetSettings.isTransparent
        val isTextBlack = widgetSettings.isTextBlack
        val customThemeColor = widgetSettings.customThemeColor
        val bump = if (isTransparent) 2f else 0f
        val hourlyBump = if (isTransparent) 1f else 0f

        return when {
            effectiveHeightDp < 210 -> WidgetSizeProfile(
                hourlyCardsVisible = hourlyCardsVisible,
                dailyCardsVisible = dailyCardsVisible,
                headingSize = 14f + bump,
                subHeadingSize = 10f + bump,
                tempSize = 28f + bump,
                hourlyTimeSize = 8f + hourlyBump,
                hourlyTempSize = 10f + hourlyBump,
                hourlyConditionSize = 7f + hourlyBump,
                dailyNameSize = 11f + bump,
                dailyTempSize = 11f + bump,
                isTransparent = isTransparent,
                isTextBlack = isTextBlack,
                customThemeColor = customThemeColor,
            )
            effectiveHeightDp < 290 -> WidgetSizeProfile(
                hourlyCardsVisible = hourlyCardsVisible,
                dailyCardsVisible = dailyCardsVisible,
                headingSize = 16f + bump,
                subHeadingSize = 11f + bump,
                tempSize = 32f + bump,
                hourlyTimeSize = 9f + hourlyBump,
                hourlyTempSize = 11f + hourlyBump,
                hourlyConditionSize = 8f + hourlyBump,
                dailyNameSize = 12f + bump,
                dailyTempSize = 12f + bump,
                isTransparent = isTransparent,
                isTextBlack = isTextBlack,
                customThemeColor = customThemeColor,
            )
            effectiveHeightDp < 360 -> WidgetSizeProfile(
                hourlyCardsVisible = hourlyCardsVisible,
                dailyCardsVisible = dailyCardsVisible,
                headingSize = 17f + bump,
                subHeadingSize = 12f + bump,
                tempSize = 36f + bump,
                hourlyTimeSize = 10f + hourlyBump,
                hourlyTempSize = 12f + hourlyBump,
                hourlyConditionSize = 9f + hourlyBump,
                dailyNameSize = 13f + bump,
                dailyTempSize = 13f + bump,
                isTransparent = isTransparent,
                isTextBlack = isTextBlack,
                customThemeColor = customThemeColor,
            )
            else -> WidgetSizeProfile(
                hourlyCardsVisible = hourlyCardsVisible,
                dailyCardsVisible = dailyCardsVisible,
                headingSize = 18f + bump,
                subHeadingSize = 13f + bump,
                tempSize = 40f + bump,
                hourlyTimeSize = 11f + hourlyBump,
                hourlyTempSize = 13f + hourlyBump,
                hourlyConditionSize = 10f + hourlyBump,
                dailyNameSize = 14f + bump,
                dailyTempSize = 14f + bump,
                isTransparent = isTransparent,
                isTextBlack = isTextBlack,
                customThemeColor = customThemeColor,
            )
        }
    }

    private fun resolveDailyCardsVisible(effectiveHeightDp: Int): Int {
        // Reserve space for the fixed header and hourly section so the bottom daily card
        // only appears when the launcher height can really support it.
        val usableHeightDp = (effectiveHeightDp - 200).coerceAtLeast(0)
        return (usableHeightDp / 46).coerceIn(0, 7)
    }

    private fun defaultHourlyCardsVisible(effectiveWidthDp: Int): Int {
        return when {
            effectiveWidthDp < 180 -> 4
            effectiveWidthDp < 240 -> 5
            else -> 6
        }
    }

    private fun defaultMinWidthDp(): Int {
        return when (widgetFamily) {
            "small" -> 110
            "medium" -> 250
            "large" -> 250
            else -> 320
        }
    }

    private fun defaultMinHeightDp(): Int {
        return when (widgetFamily) {
            "small" -> 90
            "medium" -> 110
            "large" -> 250
            else -> 250
        }
    }

    private fun bindData(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val city = widgetData.getString("wf_location_name", "WeatherFast") ?: "WeatherFast"
        val temp = widgetData.getString("wf_temperature", "--") ?: "--"
        val highLow = widgetData.getString("wf_high_low", "-- / --") ?: "-- / --"
        val condition = widgetData.getString("wf_condition_text", "Open app to set location")
            ?: "Open app to set location"
        val glyph = widgetData.getString("wf_condition_glyph", "partly") ?: "partly"

        // Bind header
        views.setTextViewText(R.id.widget_location, city)
        views.setTextViewText(R.id.widget_temp, temp)
        views.setTextViewText(R.id.widget_condition, condition)
        views.setTextViewText(R.id.widget_high_low, highLow)

        // Bind hourly data
        for (index in 1..24) {
            val hourText = widgetData.getString("wf_hour_$index", "--") ?: "--"
            val hourTemp = widgetData.getString("wf_hour_temp_$index", "--") ?: "--"
            val rawHourCondition = widgetData.getString("wf_hour_condition_$index", "--") ?: "--"
            val hourCondition = rawHourCondition.replace(Regex("(?i)\\s*\\(day\\)"), "").replace(Regex("(?i)\\s*\\(night\\)"), "")
            val hourGlyph = widgetData.getString("wf_hour_icon_$index", glyph) ?: glyph

            val cardId = context.resources.getIdentifier(
                "widget_hour_card_$index",
                "id",
                context.packageName,
            )
            
            if (hourText == "--" && hourTemp == "--") {
                if (cardId != 0) {
                    views.setViewVisibility(cardId, View.GONE)
                }
                continue
            }

            val timeId = context.resources.getIdentifier(
                "widget_hour_time_$index",
                "id",
                context.packageName,
            )
            if (timeId != 0) {
                views.setTextViewText(timeId, hourText)
            }

            val tempId = context.resources.getIdentifier(
                "widget_hour_temp_$index",
                "id",
                context.packageName,
            )
            if (tempId != 0) {
                views.setTextViewText(tempId, hourTemp)
            }

            val conditionId = context.resources.getIdentifier(
                "widget_hour_condition_$index",
                "id",
                context.packageName,
            )
            if (conditionId != 0) {
                views.setTextViewText(conditionId, hourCondition)
            }

            val iconId = context.resources.getIdentifier(
                "widget_hour_icon_$index",
                "id",
                context.packageName,
            )
            if (iconId != 0) {
                views.setImageViewResource(iconId, iconResForToken(hourGlyph))
            }
        }

        // Bind daily data
        views.setTextViewText(R.id.widget_day_name_1, widgetData.getString("wf_day_name_1", "--") ?: "--")
        views.setTextViewText(R.id.widget_day_name_2, widgetData.getString("wf_day_name_2", "--") ?: "--")
        views.setTextViewText(R.id.widget_day_name_3, widgetData.getString("wf_day_name_3", "--") ?: "--")
        views.setTextViewText(R.id.widget_day_name_4, widgetData.getString("wf_day_name_4", "--") ?: "--")
        views.setTextViewText(R.id.widget_day_name_5, widgetData.getString("wf_day_name_5", "--") ?: "--")
        views.setTextViewText(R.id.widget_day_name_6, widgetData.getString("wf_day_name_6", "--") ?: "--")
        views.setTextViewText(R.id.widget_day_name_7, widgetData.getString("wf_day_name_7", "--") ?: "--")

        views.setTextViewText(R.id.widget_day_temp_1, widgetData.getString("wf_day_temp_1", "-- / --") ?: "-- / --")
        views.setTextViewText(R.id.widget_day_temp_2, widgetData.getString("wf_day_temp_2", "-- / --") ?: "-- / --")
        views.setTextViewText(R.id.widget_day_temp_3, widgetData.getString("wf_day_temp_3", "-- / --") ?: "-- / --")
        views.setTextViewText(R.id.widget_day_temp_4, widgetData.getString("wf_day_temp_4", "-- / --") ?: "-- / --")
        views.setTextViewText(R.id.widget_day_temp_5, widgetData.getString("wf_day_temp_5", "-- / --") ?: "-- / --")
        views.setTextViewText(R.id.widget_day_temp_6, widgetData.getString("wf_day_temp_6", "-- / --") ?: "-- / --")
        views.setTextViewText(R.id.widget_day_temp_7, widgetData.getString("wf_day_temp_7", "-- / --") ?: "-- / --")

        // Bind daily icons
        views.setImageViewResource(R.id.widget_day_icon_1, iconResForToken(widgetData.getString("wf_day_icon_1", glyph) ?: glyph))
        views.setImageViewResource(R.id.widget_day_icon_2, iconResForToken(widgetData.getString("wf_day_icon_2", glyph) ?: glyph))
        views.setImageViewResource(R.id.widget_day_icon_3, iconResForToken(widgetData.getString("wf_day_icon_3", glyph) ?: glyph))
        views.setImageViewResource(R.id.widget_day_icon_4, iconResForToken(widgetData.getString("wf_day_icon_4", glyph) ?: glyph))
        views.setImageViewResource(R.id.widget_day_icon_5, iconResForToken(widgetData.getString("wf_day_icon_5", glyph) ?: glyph))
        views.setImageViewResource(R.id.widget_day_icon_6, iconResForToken(widgetData.getString("wf_day_icon_6", glyph) ?: glyph))
        views.setImageViewResource(R.id.widget_day_icon_7, iconResForToken(widgetData.getString("wf_day_icon_7", glyph) ?: glyph))
    }

    private fun iconResForToken(token: String): Int {
        return when (token.lowercase()) {
            "clear", "sun", "sunny" -> R.drawable.ic_wf_sun
            "cloud", "cloudy", "overcast" -> R.drawable.ic_wf_cloud
            "rain", "drizzle", "shower" -> R.drawable.ic_wf_rain
            "snow", "sleet", "ice" -> R.drawable.ic_wf_snow
            "storm", "thunder" -> R.drawable.ic_wf_storm
            "fog", "mist", "haze" -> R.drawable.ic_wf_fog
            else -> R.drawable.ic_wf_partly
        }
    }
}