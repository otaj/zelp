package org.zelp

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "org.zelp/downloads"
    private val relativeDir = "Zelp"

    private var pendingPickResult: MethodChannel.Result? = null

    private val pickFolderLauncher =
        registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
            val result = pendingPickResult
            pendingPickResult = null
            if (result == null) return@registerForActivityResult
            if (uri == null) {
                result.success(null)
                return@registerForActivityResult
            }
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
                val name = DocumentFile.fromTreeUri(this, uri)?.name
                    ?: uri.lastPathSegment
                    ?: uri.toString()
                result.success(
                    mapOf(
                        "uri" to uri.toString(),
                        "displayName" to name,
                    ),
                )
            } catch (e: Exception) {
                result.error("pick_failed", e.message, null)
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (fileName.isNullOrEmpty() || bytes == null) {
                            result.error("bad_args", "fileName and bytes are required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(saveToDownloads(relativeDir, fileName, bytes))
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    "saveToTreeUri" -> {
                        val treeUri = call.argument<String>("treeUri")
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (treeUri.isNullOrEmpty() || fileName.isNullOrEmpty() || bytes == null) {
                            result.error(
                                "bad_args",
                                "treeUri, fileName and bytes are required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(saveToTree(treeUri, fileName, bytes))
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    "pickOutputFolder" -> {
                        if (pendingPickResult != null) {
                            result.error("busy", "Folder picker already open", null)
                            return@setMethodCallHandler
                        }
                        pendingPickResult = result
                        pickFolderLauncher.launch(null)
                    }
                    "countFiles" -> {
                        val treeUri = call.argument<String>("treeUri")
                        try {
                            result.success(
                                if (treeUri.isNullOrEmpty()) {
                                    countDownloadsFiles()
                                } else {
                                    countTreeFiles(treeUri)
                                },
                            )
                        } catch (e: Exception) {
                            result.error("count_failed", e.message, null)
                        }
                    }
                    "clearFolder" -> {
                        val treeUri = call.argument<String>("treeUri")
                        try {
                            result.success(
                                if (treeUri.isNullOrEmpty()) {
                                    clearDownloadsFiles()
                                } else {
                                    clearTreeFiles(treeUri)
                                },
                            )
                        } catch (e: Exception) {
                            result.error("clear_failed", e.message, null)
                        }
                    }
                    "listFiles" -> {
                        val treeUri = call.argument<String>("treeUri")
                        try {
                            result.success(
                                if (treeUri.isNullOrEmpty()) {
                                    listDownloadsFiles()
                                } else {
                                    listTreeFiles(treeUri)
                                },
                            )
                        } catch (e: Exception) {
                            result.error("list_failed", e.message, null)
                        }
                    }
                    "readFileBytes" -> {
                        val treeUri = call.argument<String>("treeUri")
                        val fileName = call.argument<String>("fileName")
                        if (fileName.isNullOrEmpty()) {
                            result.error("bad_args", "fileName is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(
                                if (treeUri.isNullOrEmpty()) {
                                    readDownloadsFileBytes(fileName)
                                } else {
                                    readTreeFileBytes(treeUri, fileName)
                                },
                            )
                        } catch (e: Exception) {
                            result.error("read_failed", e.message, null)
                        }
                    }
                    "fileMd5" -> {
                        val treeUri = call.argument<String>("treeUri")
                        val fileName = call.argument<String>("fileName")
                        if (fileName.isNullOrEmpty()) {
                            result.error("bad_args", "fileName is required", null)
                            return@setMethodCallHandler
                        }
                        // Hash on a background thread — firmware files are large.
                        Thread {
                            try {
                                val hex =
                                    if (treeUri.isNullOrEmpty()) {
                                        md5DownloadsFile(fileName)
                                    } else {
                                        md5TreeFile(treeUri, fileName)
                                    }
                                runOnUiThread { result.success(hex) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("md5_failed", e.message, null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(
        relativeDir: String,
        fileName: String,
        bytes: ByteArray,
    ): String {
        val mime = guessMime(fileName)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/" + relativeDir,
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Could not open output stream")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Download/$relativeDir/$fileName"
        }

        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            relativeDir,
        )
        if (!dir.exists() && !dir.mkdirs()) {
            throw IllegalStateException("Could not create ${dir.absolutePath}")
        }
        val outFile = File(dir, fileName)
        FileOutputStream(outFile).use { it.write(bytes) }
        return outFile.absolutePath
    }

    private fun saveToTree(treeUri: String, fileName: String, bytes: ByteArray): String {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: throw IllegalStateException("Invalid folder URI")
        root.findFile(fileName)?.delete()
        val created = root.createFile(guessMime(fileName), fileName)
            ?: throw IllegalStateException("Could not create $fileName")
        contentResolver.openOutputStream(created.uri)?.use { it.write(bytes) }
            ?: throw IllegalStateException("Could not write $fileName")
        val folderName = root.name ?: "folder"
        return "$folderName/$fileName"
    }

    private fun downloadsDir(): File {
        return File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            relativeDir,
        )
    }

    private fun countDownloadsFiles(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
            val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$relativeDir%")
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID),
                selection,
                args,
                null,
            )?.use { return it.count }
            return 0
        }
        val dir = downloadsDir()
        if (!dir.exists()) return 0
        return dir.walkTopDown().count { it.isFile }
    }

    private fun clearDownloadsFiles(): Int {
        var deleted = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
            val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$relativeDir%")
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID),
                selection,
                args,
                null,
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        id,
                    )
                    if (contentResolver.delete(uri, null, null) > 0) deleted++
                }
            }
            return deleted
        }
        val dir = downloadsDir()
        if (!dir.exists()) return 0
        dir.walkBottomUp().forEach { file ->
            if (file.isFile && file.delete()) deleted++
        }
        return deleted
    }

    private fun countTreeFiles(treeUri: String): Int {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: throw IllegalStateException("Invalid folder URI")
        return countDocumentFiles(root)
    }

    private fun countDocumentFiles(dir: DocumentFile): Int {
        var count = 0
        for (child in dir.listFiles()) {
            if (child.isDirectory) {
                count += countDocumentFiles(child)
            } else if (child.isFile) {
                count++
            }
        }
        return count
    }

    private fun clearTreeFiles(treeUri: String): Int {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: throw IllegalStateException("Invalid folder URI")
        return deleteDocumentContents(root)
    }

    private fun listDownloadsFiles(): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
            val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$relativeDir%")
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(
                    MediaStore.MediaColumns.DISPLAY_NAME,
                    MediaStore.MediaColumns.RELATIVE_PATH,
                ),
                selection,
                args,
                null,
            )?.use { cursor ->
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                val pathCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH)
                while (cursor.moveToNext()) {
                    val name = cursor.getString(nameCol) ?: continue
                    val rel = cursor.getString(pathCol) ?: relativeDir
                    out.add(
                        mapOf(
                            "fileName" to name,
                            "displayPath" to "$rel$name",
                        ),
                    )
                }
            }
            return out
        }
        val dir = downloadsDir()
        if (!dir.exists()) return out
        dir.listFiles()?.forEach { file ->
            if (file.isFile) {
                out.add(
                    mapOf(
                        "fileName" to file.name,
                        "displayPath" to file.absolutePath,
                        "localPath" to file.absolutePath,
                    ),
                )
            }
        }
        return out
    }

    private fun listTreeFiles(treeUri: String): List<Map<String, String>> {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: throw IllegalStateException("Invalid folder URI")
        val folderName = root.name ?: "folder"
        return root.listFiles().mapNotNull { child ->
            if (!child.isFile) return@mapNotNull null
            val name = child.name ?: return@mapNotNull null
            mapOf(
                "fileName" to name,
                "displayPath" to "$folderName/$name",
            )
        }
    }

    private fun readDownloadsFileBytes(fileName: String): ByteArray? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val selection =
                "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?"
            val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$relativeDir%", fileName)
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID),
                selection,
                args,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                val uri = ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id)
                return contentResolver.openInputStream(uri)?.use { it.readBytes() }
            }
            return null
        }
        val file = File(downloadsDir(), fileName)
        if (!file.exists()) return null
        return file.readBytes()
    }

    private fun readTreeFileBytes(treeUri: String, fileName: String): ByteArray? {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: throw IllegalStateException("Invalid folder URI")
        val file = root.findFile(fileName) ?: return null
        return contentResolver.openInputStream(file.uri)?.use { it.readBytes() }
    }

    /** Streams file contents and returns lowercase hex MD5 (never loads whole file). */
    private fun md5Hex(input: InputStream): String {
        val digest = MessageDigest.getInstance("MD5")
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            digest.update(buffer, 0, read)
        }
        return digest.digest().joinToString("") { b -> "%02x".format(b) }
    }

    private fun md5DownloadsFile(fileName: String): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val selection =
                "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?"
            val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$relativeDir%", fileName)
            contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID),
                selection,
                args,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                val uri = ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id)
                return contentResolver.openInputStream(uri)?.use { md5Hex(it) }
            }
            return null
        }
        val file = File(downloadsDir(), fileName)
        if (!file.exists()) return null
        return FileInputStream(file).use { md5Hex(it) }
    }

    private fun md5TreeFile(treeUri: String, fileName: String): String? {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: throw IllegalStateException("Invalid folder URI")
        val file = root.findFile(fileName) ?: return null
        return contentResolver.openInputStream(file.uri)?.use { md5Hex(it) }
    }

    private fun deleteDocumentContents(dir: DocumentFile): Int {
        var deleted = 0
        for (child in dir.listFiles()) {
            if (child.isDirectory) {
                deleted += deleteDocumentContents(child)
                child.delete()
            } else if (child.isFile) {
                if (child.delete()) deleted++
            }
        }
        return deleted
    }

    private fun guessMime(fileName: String): String {
        val lower = fileName.lowercase()
        return when {
            lower.endsWith(".zip") -> "application/zip"
            lower.endsWith(".bin") -> "application/octet-stream"
            lower.endsWith(".lle") -> "application/octet-stream"
            lower.endsWith(".txt") -> "text/plain"
            else -> "application/octet-stream"
        }
    }
}
