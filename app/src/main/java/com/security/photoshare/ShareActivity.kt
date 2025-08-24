package com.security.photoshare

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

class ShareActivity : Activity() {
    companion object {
        private const val TAG = "PhotoShare"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d(TAG, "PhotoShare started")

        // Get photo path from intent
        val photoPath = intent?.getStringExtra("photo_path")

        if (!photoPath.isNullOrEmpty()) {
            Log.d(TAG, "Photo path: $photoPath")
            sharePhotoWithGarmin(photoPath)
        } else {
            Log.e(TAG, "No photo path provided")
        }

        // Close the app immediately
        finish()
    }

    private fun sharePhotoWithGarmin(photoPath: String) {
        try {
            val photoFile = File(photoPath)

            if (!photoFile.exists()) {
                Log.e(TAG, "Photo file does not exist: $photoPath")
                return
            }

            Log.d(TAG, "Photo file size: ${photoFile.length()} bytes")

            // Get URI using FileProvider
            val photoURI = FileProvider.getUriForFile(
                this,
                "com.security.photoshare.fileprovider",
                photoFile
            )

            Log.d(TAG, "Generated URI: $photoURI")

            // Create share intent specifically for Garmin Messenger
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "image/jpeg"
                putExtra(Intent.EXTRA_STREAM, photoURI)
                setPackage("com.garmin.android.apps.messenger")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            // Start Garmin Messenger with the photo
            startActivity(shareIntent)
            Log.d(TAG, "Share intent sent to Garmin Messenger")

        } catch (e: Exception) {
            Log.e(TAG, "Error sharing photo: ${e.message}", e)

            // Fallback: Open generic share dialog
            try {
                val photoFile = File(photoPath)
                val photoURI = FileProvider.getUriForFile(
                    this,
                    "com.security.photoshare.fileprovider",
                    photoFile
                )

                val fallbackIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/jpeg"
                    putExtra(Intent.EXTRA_STREAM, photoURI)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                val chooser = Intent.createChooser(fallbackIntent, "Share Photo").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(chooser)

                Log.d(TAG, "Fallback share dialog opened")

            } catch (fallbackException: Exception) {
                Log.e(TAG, "Fallback also failed: ${fallbackException.message}")
            }
        }
    }
}