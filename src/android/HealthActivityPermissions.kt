package com.axians.requestexercisepermissionsplugin

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import org.apache.cordova.CordovaActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.platform.client.proto.PermissionProto.Permission
import java.util.Set
import java.util.LinkedHashSet
import kotlin.jvm.internal.Reflection

class HealthActivityPermissions : CordovaActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Toast.makeText(this.baseContext, "say now", Toast.LENGTH_SHORT).show()

        // Create a set of permissions for required data types
        val PERMISSIONS =
            setOf(
                HealthPermission.getReadPermission(HeartRateRecord::class),
                HealthPermission.getWritePermission(HeartRateRecord::class),
                HealthPermission.getReadPermission(StepsRecord::class),
                HealthPermission.getWritePermission(StepsRecord::class),
                HealthPermission.getReadPermission(ExerciseSessionRecord::class),
                HealthPermission.getWritePermission(ExerciseSessionRecord::class)
            )
        /*
          * Launch PermissionsActivity
          */
        // Create the permissions launcher
        val requestPermissionActivityContract = PermissionController.createRequestPermissionResultContract()

        val requestPermissions = registerForActivityResult(requestPermissionActivityContract) { granted ->
            if (granted.containsAll(PERMISSIONS)) {
                // Permissions successfully granted
            } else {
                // Lack of required permissions
            }
        }
        requestPermissions.launch(PERMISSIONS)

        suspend fun checkPermissionsAndRun(healthConnectClient: HealthConnectClient) {
            val granted = healthConnectClient.permissionController.getGrantedPermissions()
            if (granted.containsAll(PERMISSIONS)) {
                // Permissions already granted; proceed with inserting or reading data
            } else {
                requestPermissions.launch(PERMISSIONS)
            }
        }
        finish() // Finish this new activity
    }
}
