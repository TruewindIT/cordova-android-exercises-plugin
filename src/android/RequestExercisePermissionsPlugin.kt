package com.axians.requestexercisepermissionsplugin

import android.content.Intent
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import androidx.health.connect.client.time.TimeRangeFilter
import com.google.gson.Gson
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
                runBlocking {
                    val allSet = async {
                        checkPermissions()
                    }.await()
                    if (allSet) {
                        callbackContext.sendPluginResult(PluginResult(PluginResult.Status.OK))
                    } else {
                        requestPermissions(callbackContext)
                        callbackContext.sendPluginResult(PluginResult(PluginResult.Status.OK))
                    }
                    true
                }
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
        val allSet = async {
            checkPermissions()
        }.await()
        if (!allSet) {
            val message = "Not all necessary permissions were given. Add all fitness permissions on your device settings."
            callbackContext.sendPluginResult(PluginResult(PluginResult.Status.ERROR, message))
            return@runBlocking
        }
        val exercises: List<ExerciseSessionRecord> = async {
            fetchExerciseData(startTime, endTime)
        }.await()
        val response = mutableListOf<Map<String, Any>>()
        for (exerciseRecord in exercises) {

            val samples = mutableListOf<Map<String, Any>>()

            val distance = async {
                readDistanceData(exerciseRecord.startTime, exerciseRecord.endTime)
            }.await()

            val calories = async {
                readTotalCaloriesBurned(exerciseRecord.startTime, exerciseRecord.endTime)
            }.await()

            val decimalCaloriesList = mutableListOf<Double>()
            val activeCalories = async {
                readActiveCaloriesBurned(exerciseRecord.startTime, exerciseRecord.endTime)
            }.await()
            decimalCaloriesList.add(activeCalories)

            val heartRates = async {
                readHeartRateValues(exerciseRecord.startTime, exerciseRecord.endTime)
            }.await()

            samples.add(
                mapOf(
                    "startDate" to exerciseRecord.startTime.toString(),
                    "endDate" to exerciseRecord.endTime.toString(),
                    "block" to 1,
                    "values" to decimalCaloriesList,
                    "additionalData" to "ACTIVE_CALORIES_BURNED"
                    )
                )
            samples.add(
                    mapOf(
                        "startDate" to exerciseRecord.startTime.toString(),
                        "endDate" to exerciseRecord.endTime.toString(),
                        "block" to 1,
                        "values" to heartRates,
                        "additionalData" to "HEART_RATE"
                    )
                )

            response.add(
                mapOf(
                    "startDate" to exerciseRecord.startTime.toString(),
                    "endDate" to exerciseRecord.endTime.toString(),
                    "duration" to Duration.between(exerciseRecord.startTime, exerciseRecord.endTime).seconds,
                    "activity" to getExerciseTypeString(exerciseRecord.exerciseType),
                    "totalDistance" to distance,
                    "totalEnergyBurned" to calories,
                    "samples" to samples
                ))
        }
       callbackContext.sendPluginResult(PluginResult(PluginResult.Status.OK, Gson().toJson(response)))
    }

    private suspend fun fetchExerciseData(startTime: Instant, endTime: Instant): List<ExerciseSessionRecord> {
        val healthConnectClient = HealthConnectClient.getOrCreate(cordova.context)
        val request = ReadRecordsRequest(
            recordType = ExerciseSessionRecord::class,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
        val response: ReadRecordsResponse<ExerciseSessionRecord> = healthConnectClient.readRecords(request)
        return response.records
    }

    private suspend fun readDistanceData(startTime: Instant, endTime: Instant): Double {
        var distance = 0.0
        try {
            val healthConnectClient = HealthConnectClient.getOrCreate(cordova.context)
            val timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
            val request = ReadRecordsRequest(
                recordType = DistanceRecord::class,
                timeRangeFilter = timeRangeFilter
            )
            val response = healthConnectClient.readRecords(request)
            response.records.forEach { distanceRecord ->
                    distance += distanceRecord.distance.inMeters
            }

        } catch (e: Exception) {
            println(e.message)
            distance = 0.0
        }
        return distance
    }

    private suspend fun readTotalCaloriesBurned(startTime: Instant, endTime: Instant): Double {
        var calories = 0.0
        try {
            val healthConnectClient = HealthConnectClient.getOrCreate(cordova.context)

            val timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
            val request = ReadRecordsRequest(
                recordType = TotalCaloriesBurnedRecord::class,
                timeRangeFilter = timeRangeFilter
            )
            val response = healthConnectClient.readRecords(request)
            response.records.forEach { caloriesRecord ->
                calories += caloriesRecord.energy.inKilocalories
            }
        } catch (e: Exception) {
            println(e.message)
            calories = 0.0
        }
        return calories
    }

    private suspend fun readHeartRateValues(startTime: Instant, endTime: Instant): List<Double> {
        var heartRatesList = mutableListOf<Double>()
        try {
            val healthConnectClient = HealthConnectClient.getOrCreate(cordova.context)

            val timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
            val request = ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = timeRangeFilter
            )
            val response = healthConnectClient.readRecords(request)
            response.records.forEach { heartRateRecord ->
                heartRateRecord.samples.forEach { bpm ->
                    heartRatesList.add(bpm.beatsPerMinute.toDouble())
                }
            }
        } catch (e: Exception) {
            println(e.message)
        }
        return heartRatesList
    }

    private suspend fun readActiveCaloriesBurned(startTime: Instant, endTime: Instant): Double {
        var calories = 0.0
        try {
            val healthConnectClient = HealthConnectClient.getOrCreate(cordova.context)

            val timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
            val request = ReadRecordsRequest(
                recordType = ActiveCaloriesBurnedRecord::class,
                timeRangeFilter = timeRangeFilter
            )
            val response = healthConnectClient.readRecords(request)
            println(response.records)
            response.records.forEach { caloriesRecord ->
                calories += caloriesRecord.energy.inKilocalories
            }
        } catch (e: Exception) {
            calories = 0.0
        }
        return calories
    }

    private suspend fun checkPermissions(): Boolean{
        val permissions = getPermissionsSet()
        val grantedPermissions = HealthConnectClient.getOrCreate(cordova.context).permissionController.getGrantedPermissions()
        if (!grantedPermissions.containsAll(permissions)) {
            println("not all ghgranted.")
            return false
        } else {
            println("All permissions already granted.")
            return true
        }
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
    companion object {
        fun getPermissionsSet(): Set<String> {
            val permissions = setOf(
                HealthPermission.getReadPermission(HeartRateRecord::class),
                HealthPermission.getReadPermission(StepsRecord::class),
                HealthPermission.getReadPermission(ExerciseSessionRecord::class),
                HealthPermission.getReadPermission(DistanceRecord::class),
                HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
                HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
                HealthPermission.getReadPermission(SpeedRecord::class)
            )
            return permissions
        }
    }
}
