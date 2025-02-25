package com.axians.requestexercisepermissionsplugin

import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.*
import org.apache.cordova.CallbackContext
import org.apache.cordova.CordovaInterface
import org.apache.cordova.CordovaPlugin
import org.apache.cordova.CordovaWebView
import org.apache.cordova.PluginResult
import org.json.JSONArray
import org.json.JSONException
import java.time.Duration
import java.time.Instant


class RequestExercisePermissionsPlugin : CordovaPlugin() {

    private var callbackContext: CallbackContext? = null

    override fun initialize(cordova: CordovaInterface, webView: CordovaWebView) {
        super.initialize(cordova, webView)
    }

    @Throws(JSONException::class)
    override fun execute(
        action: String,
        args: JSONArray,
        callbackContext: CallbackContext
    ): Boolean {

        this.callbackContext = callbackContext

        return when (action) {
            "requestPermissions" -> {
                requestPermissions(callbackContext)
                true
            }
            "getExerciseData" -> {
                val startTime: Instant= Instant.parse(args.getString(0))
                val endTime: Instant= Instant.parse(args.getString(1))
                getExerciseData(startTime, endTime, callbackContext)
                true
            }
            else -> false
        }
    }

    private fun requestPermissions(callbackContext: CallbackContext) {
        val i = Intent(this.cordova.context, HealthActivityPermissions::class.java)
        this.cordova.context.startActivity(i)
    }

    private fun getExerciseData(startTime: Instant, endTime: Instant, callbackContext: CallbackContext)  = runBlocking {
        val deferred: Deferred<List<ExerciseSessionRecord>> = async {
            fetchExerciseData(startTime, endTime)
        }
        val result: List<ExerciseSessionRecord> = deferred.await()
        val response = mutableListOf<Map<String, Any>>()
        for (exerciseRecord in result) {
            response.add(
                mapOf(
                    "startDate" to exerciseRecord.startTime,
                    "endDate" to exerciseRecord.endTime,
                    "duration" to Duration.between(exerciseRecord.startTime, exerciseRecord.endTime).seconds,
                    "Activity" to getExerciseTypeString(exerciseRecord.exerciseType)
                ))
        }
       callbackContext.sendPluginResult(PluginResult(PluginResult.Status.OK, response.toString()))
    }

    suspend fun fetchExerciseData(startTime: Instant, endTime: Instant): List<ExerciseSessionRecord> {
        val healthConnectClient = HealthConnectClient.getOrCreate(cordova.context)
        val request = ReadRecordsRequest(
            recordType = ExerciseSessionRecord::class,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
        val response: ReadRecordsResponse<ExerciseSessionRecord> = healthConnectClient.readRecords(request)
        return response.records
    }

    //extracted from ExerciseSessionRecord.ExerciseTypes and https://developer.android.com/reference/kotlin/androidx/health/services/client/data/ExerciseType#fromId(kotlin.Int)
    fun getExerciseTypeString(exerciseTypeId: Int): String {
        return when (exerciseTypeId) {
            0 -> "unknown"
            2 -> "badminton"
            4 -> "baseball"
            5 -> "basketball"
            8 -> "biking"
            9 -> "biking_stationary"
            10 -> "boot_camp"
            11 -> "boxing"
            13 -> "calisthenics"
            14 -> "cricket"
            16 -> "dancing"
            25 -> "elliptical"
            26 -> "exercise_class"
            27 -> "fencing"
            28 -> "football_american"
            29 -> "football_australian"
            31 -> "frisbee_disc"
            32 -> "golf"
            33 -> "guided_breathing"
            34 -> "gymnastics"
            35 -> "handball"
            36 -> "high_intensity_interval_training"
            37 -> "hiking"
            38 -> "ice_hockey"
            39 -> "ice_skating"
            44 -> "martial_arts"
            46 -> "paddling"
            47 -> "para_gliding"
            48 -> "pilates"
            50 -> "racquetball"
            51 -> "rock_climbing"
            52 -> "roller_hockey"
            53 -> "rowing"
            54 -> "rowing_machine"
            55 -> "rugby"
            56 -> "running"
            57 -> "running_treadmill"
            58 -> "sailing"
            59 -> "scuba_diving"
            60 -> "skating"
            61 -> "skiing"
            62 -> "snowboarding"
            63 -> "snowshoeing"
            64 -> "soccer"
            65 -> "softball"
            66 -> "squash"
            68 -> "stair_climbing"
            69 -> "stair_climbing_machine"
            70 -> "strength_training"
            71 -> "stretching"
            72 -> "surfing"
            73 -> "swimming_open_water"
            74 -> "swimming_pool"
            75 -> "table_tennis"
            76 -> "tennis"
            78 -> "volleyball"
            79 -> "walking"
            80 -> "water_polo"
            81 -> "weightlifting"
            82 -> "wheelchair"
            83 -> "yoga"
            else -> "unknown"
        }
    }
}