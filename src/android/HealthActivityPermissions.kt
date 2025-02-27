package com.axians.requestexercisepermissionsplugin

import android.os.Bundle
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import org.apache.cordova.CordovaActivity

class HealthActivityPermissions : CordovaActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Create a set of permissions for required data types
        val permissions = RequestExercisePermissionsPlugin.getPermissionsSet()
        /*
          * Launch PermissionsActivity
          */
        // Create the permissions launcher
        val requestPermissionActivityContract = PermissionController.createRequestPermissionResultContract()

        val requestPermissions = registerForActivityResult(requestPermissionActivityContract) { granted ->
            if (granted.containsAll(permissions)) {
                println("all granted")
            } else {
                println("not all granted")
            }
        }
        requestPermissions.launch(permissions)

        suspend fun checkPermissionsAndRun(healthConnectClient: HealthConnectClient) {
            val granted = healthConnectClient.permissionController.getGrantedPermissions()
            if (granted.containsAll(permissions)) {
                // Permissions already granted; proceed with inserting or reading data
            } else {
                requestPermissions.launch(permissions)
            }
        }
        finish() // Finish this new activity
    }
}
