package dev.halixm.temanlari

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var backupChannel: MethodChannel? = null
    private var pendingBackup: PendingBackup? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.halixm.temanlari/backup",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "saveBackup") startBackup(call, result)
                else result.notImplemented()
            }
        }
    }

    private fun startBackup(call: MethodCall, result: MethodChannel.Result) {
        if (pendingBackup != null) {
            result.error("backup_busy", "Finish the current backup first.", null)
            return
        }
        val filename = call.argument<String>("filename")
        val bytes = call.argument<ByteArray>("bytes")
        if (filename.isNullOrBlank() || bytes == null || bytes.size > MAX_BYTES) {
            result.error("backup_invalid", "Could not prepare the backup. Try again.", null)
            return
        }
        pendingBackup = PendingBackup(bytes, result)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, filename)
        }
        try {
            startActivityForResult(intent, BACKUP_REQUEST)
        } catch (_: Exception) {
            failPending("Could not open a save location. Try again.")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != BACKUP_REQUEST) return
        val request = pendingBackup ?: return
        if (resultCode == Activity.RESULT_CANCELED) {
            complete(request, "cancelled")
            return
        }
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            failPending("Backup was not saved. Choose a location and try again.")
            return
        }
        Thread({ writeBackup(request, uri) }, "backup-document-writer").start()
    }

    private fun writeBackup(request: PendingBackup, uri: Uri) {
        try {
            val output = contentResolver.openOutputStream(uri, "w")
                ?: throw IOException("Save location did not provide an output stream")
            output.use {
                it.write(request.bytes)
                it.flush()
            }
            // use() has closed the stream successfully before completion.
            runOnUiThread { complete(request, "saved") }
        } catch (_: Exception) {
            val deleted = deleteFailedDocument(uri)
            val message = if (deleted) {
                "Could not save backup. Check available space and try another folder."
            } else {
                "Could not save backup. A partial file may remain. Try another folder."
            }
            runOnUiThread {
                if (pendingBackup === request) failPending(message)
            }
        }
    }

    private fun deleteFailedDocument(uri: Uri): Boolean = try {
        // ACTION_CREATE_DOCUMENT creates a new document; never delete other paths.
        DocumentsContract.deleteDocument(contentResolver, uri)
    } catch (_: Exception) {
        false
    }

    private fun complete(request: PendingBackup, outcome: String) {
        if (pendingBackup !== request) return
        pendingBackup = null
        request.result.success(outcome)
    }

    private fun failPending(message: String) {
        val request = pendingBackup ?: return
        pendingBackup = null
        request.result.error("backup_failed", message, null)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        backupChannel?.setMethodCallHandler(null)
        backupChannel = null
        failPending("Backup was interrupted. Please try again.")
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        failPending("Backup was interrupted. Please try again.")
        super.onDestroy()
    }

    private data class PendingBackup(val bytes: ByteArray, val result: MethodChannel.Result)

    companion object {
        private const val BACKUP_REQUEST = 7401
        private const val MAX_BYTES = 50 * 1024 * 1024
    }
}
