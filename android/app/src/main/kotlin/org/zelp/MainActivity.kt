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
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "org.zelp/downloads"
    private val defaultRelativeDir = "Zelp"

    private var pendingPickResult: MethodChannel.Result? = null

    private val pickFolderLauncher =
        registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
            val result = pendingPickResult
            pendingPickResult = null
            if (result == null) {
                return@registerForActivityResult
            }
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
            .setMethodCallHandler { call, result -> dispatchMethodCall(call, result) }
    }

    private fun dispatchMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveToDownloads" -> handleSaveToDownloads(call, result)
            "saveToTreeUri" -> handleSaveToTreeUri(call, result)
            "pickOutputFolder" -> handlePickOutputFolder(result)
            "countFiles" -> handleCountFiles(call, result)
            "clearFolder" -> handleClearFolder(call, result)
            "listFiles" -> handleListFiles(call, result)
            "readFileBytes" -> handleReadFileBytes(call, result)
            "fileMd5" -> handleFileMd5(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleSaveToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")
        val relativeDir = call.argument<String>("relativeDir") ?: defaultRelativeDir
        if (fileName.isNullOrEmpty() || bytes == null) {
            result.error("bad_args", "fileName and bytes are required", null)
            return
        }
        try {
            result.success(saveToDownloads(relativeDir, fileName, bytes))
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    private fun handleSaveToTreeUri(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("treeUri")
        val fileName = call.argument<String>("fileName")
        val bytes = call.argument<ByteArray>("bytes")
        val relativeDir = call.argument<String>("relativeDir")
        if (treeUri.isNullOrEmpty() || fileName.isNullOrEmpty() || bytes == null) {
            result.error(
                "bad_args",
                "treeUri, fileName and bytes are required",
                null,
            )
            return
        }
        try {
            result.success(saveToTree(treeUri, fileName, bytes, relativeDir))
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    private fun handlePickOutputFolder(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "Folder picker already open", null)
            return
        }
        pendingPickResult = result
        pickFolderLauncher.launch(null)
    }

    private fun handleCountFiles(call: MethodCall, result: MethodChannel.Result) {
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

    private fun handleClearFolder(call: MethodCall, result: MethodChannel.Result) {
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

    private fun handleListFiles(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("treeUri")
        val relativeDir = call.argument<String>("relativeDir") ?: defaultRelativeDir
        try {
            result.success(
                if (treeUri.isNullOrEmpty()) {
                    listDownloadsFiles(relativeDir)
                } else {
                    listTreeFiles(treeUri, relativeDir)
                },
            )
        } catch (e: Exception) {
            result.error("list_failed", e.message, null)
        }
    }

    private fun handleReadFileBytes(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("treeUri")
        val fileName = call.argument<String>("fileName")
        val relativeDir = call.argument<String>("relativeDir") ?: defaultRelativeDir
        if (fileName.isNullOrEmpty()) {
            result.error("bad_args", "fileName is required", null)
            return
        }
        try {
            result.success(
                if (treeUri.isNullOrEmpty()) {
                    readDownloadsFileBytes(relativeDir, fileName)
                } else {
                    readTreeFileBytes(treeUri, fileName, relativeDir)
                },
            )
        } catch (e: Exception) {
            result.error("read_failed", e.message, null)
        }
    }

    private fun handleFileMd5(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("treeUri")
        val fileName = call.argument<String>("fileName")
        val relativeDir = call.argument<String>("relativeDir") ?: defaultRelativeDir
        if (fileName.isNullOrEmpty()) {
            result.error("bad_args", "fileName is required", null)
            return
        }
        // Hash on a background thread — firmware files are large.
        Thread {
            try {
                val hex =
                    if (treeUri.isNullOrEmpty()) {
                        md5DownloadsFile(relativeDir, fileName)
                    } else {
                        md5TreeFile(treeUri, fileName, relativeDir)
                    }
                runOnUiThread { result.success(hex) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("md5_failed", e.message, null)
                }
            }
        }.start()
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
                ?: error("MediaStore insert failed")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: error("Could not open output stream")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Download/$relativeDir/$fileName"
        }

        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            relativeDir,
        )
        check(dir.exists() || dir.mkdirs()) {
            "Could not create ${dir.absolutePath}"
        }
        val outFile = File(dir, fileName)
        FileOutputStream(outFile).use { it.write(bytes) }
        return outFile.absolutePath
    }

    private fun saveToTree(
        treeUri: String,
        fileName: String,
        bytes: ByteArray,
        relativeDir: String?,
    ): String {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: error("Invalid folder URI")
        val dir = resolveTreeDir(root, relativeDir)
        dir.findFile(fileName)?.delete()
        val created = dir.createFile(guessMime(fileName), fileName)
            ?: error("Could not create $fileName")
        contentResolver.openOutputStream(created.uri)?.use { it.write(bytes) }
            ?: error("Could not write $fileName")
        val folderName = dir.name ?: "folder"
        return "$folderName/$fileName"
    }

    /**
     * For SAF: [relativeDir] from Dart is either null/"Zelp" (root of the picked
     * tree) or a single child name like "fw" / "apps" under that tree.
     */
    private fun resolveTreeDir(root: DocumentFile, relativeDir: String?): DocumentFile {
        val sub = treeSubfolderName(relativeDir) ?: return root
        root.findFile(sub)?.let { existing ->
            if (existing.isDirectory) {
                return existing
            }
            existing.delete()
        }
        return root.createDirectory(sub)
            ?: error("Could not create subfolder $sub")
    }

    private fun findTreeDir(root: DocumentFile, relativeDir: String?): DocumentFile? {
        val sub = treeSubfolderName(relativeDir) ?: return root
        val child = root.findFile(sub) ?: return null
        return if (child.isDirectory) {
            child
        } else {
            null
        }
    }

    /** Child folder under the SAF tree, or null to use the tree root. */
    private fun treeSubfolderName(relativeDir: String?): String? {
        if (relativeDir.isNullOrEmpty() || relativeDir == defaultRelativeDir) {
            return null
        }
        // Dart may pass "Zelp/fw" for MediaStore; SAF only needs the last segment.
        val last = relativeDir.substringAfterLast('/')
        return last.takeIf { it.isNotEmpty() && it != defaultRelativeDir }
    }

    private fun downloadsDir(relativeDir: String = defaultRelativeDir): File {
        return File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            relativeDir,
        )
    }

    private fun countDownloadsFiles(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
            val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$defaultRelativeDir%")
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
        if (!dir.exists()) {
            return 0
        }
        return dir.walkTopDown().count { it.isFile }
    }

    private fun clearDownloadsFiles(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            clearMediaStoreDownloads()
        } else {
            clearLegacyDownloadsDir()
        }
    }

    private fun clearMediaStoreDownloads(): Int {
        var deleted = 0
        val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
        val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$defaultRelativeDir%")
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
                if (contentResolver.delete(uri, null, null) > 0) {
                    deleted++
                }
            }
        }
        return deleted
    }

    private fun clearLegacyDownloadsDir(): Int {
        var deleted = 0
        val dir = downloadsDir()
        if (!dir.exists()) {
            return 0
        }
        dir.walkBottomUp().forEach { file ->
            if (file.isFile && file.delete()) {
                deleted++
            }
        }
        return deleted
    }

    private fun countTreeFiles(treeUri: String): Int {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: error("Invalid folder URI")
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
            ?: error("Invalid folder URI")
        return deleteDocumentContents(root)
    }

    private fun listDownloadsFiles(relativeDir: String): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            listMediaStoreDownloads(relativeDir, out)
            return out
        }
        val dir = downloadsDir(relativeDir)
        if (!dir.exists()) {
            return out
        }
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

    /** Exact folder match: RELATIVE_PATH is typically "Download/Zelp/fw/". */
    private fun listMediaStoreDownloads(relativeDir: String, out: MutableList<Map<String, String>>) {
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
            val prefix = "${Environment.DIRECTORY_DOWNLOADS}/$relativeDir"
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameCol)
                val rel = cursor.getString(pathCol) ?: relativeDir
                // Exclude deeper nested dirs (and siblings) when listing a parent path;
                // require the path to end exactly at relativeDir.
                val normalized = rel.trimEnd('/')
                if (name == null || normalized != prefix) {
                    continue
                }
                out.add(
                    mapOf(
                        "fileName" to name,
                        "displayPath" to "$rel$name",
                    ),
                )
            }
        }
    }

    private fun listTreeFiles(treeUri: String, relativeDir: String): List<Map<String, String>> {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: error("Invalid folder URI")
        val dir = findTreeDir(root, relativeDir) ?: return emptyList()
        val folderName = dir.name ?: "folder"
        return dir.listFiles().mapNotNull { child ->
            if (!child.isFile) {
                return@mapNotNull null
            }
            val name = child.name ?: return@mapNotNull null
            mapOf(
                "fileName" to name,
                "displayPath" to "$folderName/$name",
            )
        }
    }

    private fun readDownloadsFileBytes(relativeDir: String, fileName: String): ByteArray? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return readMediaStoreFileBytes(relativeDir, fileName)
        }
        val file = File(downloadsDir(relativeDir), fileName)
        if (!file.exists()) {
            return null
        }
        return file.readBytes()
    }

    private fun readMediaStoreFileBytes(relativeDir: String, fileName: String): ByteArray? {
        val selection =
            "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?"
        val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$relativeDir%", fileName)
        contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.RELATIVE_PATH),
            selection,
            args,
            null,
        )?.use { cursor ->
            val pathCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH)
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val prefix = "${Environment.DIRECTORY_DOWNLOADS}/$relativeDir"
            while (cursor.moveToNext()) {
                val rel = (cursor.getString(pathCol) ?: "").trimEnd('/')
                if (rel != prefix) {
                    continue
                }
                val id = cursor.getLong(idCol)
                val uri = ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id)
                return contentResolver.openInputStream(uri)?.use { it.readBytes() }
            }
        }
        return null
    }

    private fun readTreeFileBytes(
        treeUri: String,
        fileName: String,
        relativeDir: String,
    ): ByteArray? {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: error("Invalid folder URI")
        val dir = findTreeDir(root, relativeDir) ?: return null
        val file = dir.findFile(fileName) ?: return null
        return contentResolver.openInputStream(file.uri)?.use { it.readBytes() }
    }

    /** Streams file contents and returns lowercase hex MD5 (never loads whole file). */
    private fun md5Hex(input: InputStream): String {
        val digest = MessageDigest.getInstance("MD5")
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val read = input.read(buffer)
            if (read < 0) {
                break
            }
            digest.update(buffer, 0, read)
        }
        return digest.digest().joinToString("") { b -> "%02x".format(b) }
    }

    private fun md5DownloadsFile(relativeDir: String, fileName: String): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return md5MediaStoreFile(relativeDir, fileName)
        }
        val file = File(downloadsDir(relativeDir), fileName)
        if (!file.exists()) {
            return null
        }
        return FileInputStream(file).use { md5Hex(it) }
    }

    private fun md5MediaStoreFile(relativeDir: String, fileName: String): String? {
        val selection =
            "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?"
        val args = arrayOf("%${Environment.DIRECTORY_DOWNLOADS}/$relativeDir%", fileName)
        contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.RELATIVE_PATH),
            selection,
            args,
            null,
        )?.use { cursor ->
            val pathCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH)
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val prefix = "${Environment.DIRECTORY_DOWNLOADS}/$relativeDir"
            while (cursor.moveToNext()) {
                val rel = (cursor.getString(pathCol) ?: "").trimEnd('/')
                if (rel != prefix) {
                    continue
                }
                val id = cursor.getLong(idCol)
                val uri = ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id)
                return contentResolver.openInputStream(uri)?.use { md5Hex(it) }
            }
        }
        return null
    }

    private fun md5TreeFile(treeUri: String, fileName: String, relativeDir: String): String? {
        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
            ?: error("Invalid folder URI")
        val dir = findTreeDir(root, relativeDir) ?: return null
        val file = dir.findFile(fileName) ?: return null
        return contentResolver.openInputStream(file.uri)?.use { md5Hex(it) }
    }

    private fun deleteDocumentContents(dir: DocumentFile): Int {
        var deleted = 0
        for (child in dir.listFiles()) {
            if (child.isDirectory) {
                deleted += deleteDocumentContents(child)
                child.delete()
            } else if (child.isFile) {
                if (child.delete()) {
                    deleted++
                }
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
