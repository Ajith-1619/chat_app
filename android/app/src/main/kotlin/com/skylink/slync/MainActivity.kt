package com.skylink.slync

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val contactPickRequestCode = 4207
    private val shareChannelName = "skylink/share_intent"
    private var pendingContactResult: MethodChannel.Result? = null
    private var shareChannel: MethodChannel? = null
    private var pendingSharePayload: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "skylink/android_settings"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWirelessSettings" -> {
                    startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                    result.success(null)
                }
                "pickContact" -> pickContact(result)
                "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "savePublicDownload" -> savePublicDownload(
                    call.argument<String>("sourcePath"),
                    call.argument<String>("fileName"),
                    call.argument<String>("mimeType"),
                    call.argument<String>("mediaType"),
                    result,
                )
                else -> result.notImplemented()
            }
        }
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialShare" -> {
                        val payload = pendingSharePayload ?: sharePayloadFromIntent(intent)
                        pendingSharePayload = null
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        pendingSharePayload = sharePayloadFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = sharePayloadFromIntent(intent) ?: return
        pendingSharePayload = payload
        shareChannel?.invokeMethod("incomingShare", payload)
    }

    private fun sharePayloadFromIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return null
        val files = sharedUrisFrom(intent).mapNotNull { uri -> sharedFilePayload(uri) }
        val text = intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT).orEmpty()
        if (files.isEmpty() && text.isBlank()) return null
        return mapOf(
            "text" to text,
            "subject" to subject,
            "files" to files,
            "receivedAt" to System.currentTimeMillis().toString(),
        )
    }

    @Suppress("DEPRECATION")
    private fun sharedUrisFrom(intent: Intent): List<Uri> {
        val uris = mutableListOf<Uri>()
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
        } else {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
        }
        return uris.distinctBy { it.toString() }
    }

    private fun sharedFilePayload(uri: Uri): Map<String, Any?>? {
        return try {
            val name = displayNameFor(uri).ifBlank { "shared-file-${System.currentTimeMillis()}" }
            val target = copySharedUriToCache(uri, name)
            mapOf(
                "uri" to uri.toString(),
                "path" to target.absolutePath,
                "name" to name,
                "mimeType" to (contentResolver.getType(uri) ?: "application/octet-stream"),
                "size" to target.length(),
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun displayNameFor(uri: Uri): String {
        var name = ""
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                name = cursor.getString(nameIndex).orEmpty()
            }
        }
        if (name.isBlank()) name = uri.lastPathSegment.orEmpty().substringAfterLast('/')
        return sanitizeSharedFileName(name)
    }

    private fun sanitizeSharedFileName(value: String): String {
        val cleaned = value.trim().replace(Regex("[^A-Za-z0-9._ -]"), "_")
        return cleaned.ifBlank { "shared-file" }
    }

    private fun copySharedUriToCache(uri: Uri, displayName: String): File {
        val targetDir = File(cacheDir, "incoming_shares")
        if (!targetDir.exists()) targetDir.mkdirs()
        val target = File(
            targetDir,
            "${System.currentTimeMillis()}-${UUID.randomUUID()}-${sanitizeSharedFileName(displayName)}",
        )
        contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IllegalStateException("Unable to read shared file.")
        return target
    }

    private fun savePublicDownload(
        sourcePath: String?,
        fileName: String?,
        mimeType: String?,
        mediaType: String?,
        result: MethodChannel.Result,
    ) {
        val source = sourcePath?.let { File(it) }
        val safeName = fileName?.trim().orEmpty()
        if (source == null || !source.exists()) {
            result.error("missing_source", "Downloaded file was not found.", null)
            return
        }
        if (safeName.isEmpty()) {
            result.error("missing_name", "Downloaded file name is missing.", null)
            return
        }
        try {
            val resolvedMime = mimeType?.takeIf { it.isNotBlank() } ?: "application/octet-stream"
            val resolvedType = mediaType?.takeIf { it.isNotBlank() } ?: "file"
            val savedPath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveToMediaStore(source, safeName, resolvedMime, resolvedType)
            } else {
                saveToLegacyPublicDirectory(source, safeName, resolvedMime, resolvedType)
            }
            result.success(savedPath)
        } catch (error: Exception) {
            result.error("save_failed", "Unable to save the download publicly.", error.message)
        }
    }

    private fun saveToMediaStore(
        source: File,
        fileName: String,
        mimeType: String,
        mediaType: String,
    ): String {
        val (collection, relativePath) = mediaStoreTargetFor(mediaType)
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = applicationContext.contentResolver
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore insert failed.")
        resolver.openOutputStream(uri)?.use { output ->
            source.inputStream().use { input ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("Unable to open MediaStore output stream.")
        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return "$relativePath/$fileName"
    }

    private fun saveToLegacyPublicDirectory(
        source: File,
        fileName: String,
        mimeType: String,
        mediaType: String,
    ): String {
        val (baseDirectory, _) = legacyTargetFor(mediaType)
        val targetDir = File(
            Environment.getExternalStoragePublicDirectory(baseDirectory),
            "Skylink"
        )
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }
        val targetFile = File(targetDir, fileName)
        source.copyTo(targetFile, overwrite = true)
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(targetFile.absolutePath),
            arrayOf(mimeType),
            null,
        )
        return targetFile.absolutePath
    }

    private fun mediaStoreTargetFor(mediaType: String): Pair<android.net.Uri, String> {
        return when (mediaType.lowercase()) {
            "image" -> Pair(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                Environment.DIRECTORY_PICTURES + "/Skylink",
            )
            "video" -> Pair(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                Environment.DIRECTORY_MOVIES + "/Skylink",
            )
            "audio" -> Pair(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                Environment.DIRECTORY_MUSIC + "/Skylink",
            )
            else -> Pair(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                Environment.DIRECTORY_DOWNLOADS + "/Skylink",
            )
        }
    }

    private fun legacyTargetFor(mediaType: String): Pair<String, String> {
        return when (mediaType.lowercase()) {
            "image" -> Pair(Environment.DIRECTORY_PICTURES, "Skylink")
            "video" -> Pair(Environment.DIRECTORY_MOVIES, "Skylink")
            "audio" -> Pair(Environment.DIRECTORY_MUSIC, "Skylink")
            else -> Pair(Environment.DIRECTORY_DOWNLOADS, "Skylink")
        }
    }

    private fun pickContact(result: MethodChannel.Result) {
        if (pendingContactResult != null) {
            result.error("busy", "Another contact picker is already open.", null)
            return
        }
        pendingContactResult = result
        val intent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
        try {
            startActivityForResult(intent, contactPickRequestCode)
        } catch (error: Exception) {
            pendingContactResult = null
            result.error("unavailable", "Unable to open contacts.", error.message)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != contactPickRequestCode) return
        val result = pendingContactResult ?: return
        pendingContactResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.error("cancelled", "Contact selection cancelled.", null)
            return
        }
        try {
            val contactUri = data.data!!
            var contactId = ""
            var displayName = ""
            contentResolver.query(
                contactUri,
                arrayOf(ContactsContract.Contacts._ID, ContactsContract.Contacts.DISPLAY_NAME_PRIMARY),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    contactId = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID)) ?: ""
                    displayName = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME_PRIMARY)) ?: ""
                }
            }
            val phones = mutableListOf<String>()
            if (contactId.isNotEmpty()) {
                contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                    "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                    arrayOf(contactId),
                    null
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val phone = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)) ?: ""
                        if (phone.isNotBlank() && !phones.contains(phone)) phones.add(phone)
                    }
                }
            }
            val emails = mutableListOf<String>()
            if (contactId.isNotEmpty()) {
                contentResolver.query(
                    ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                    arrayOf(ContactsContract.CommonDataKinds.Email.ADDRESS),
                    "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?",
                    arrayOf(contactId),
                    null
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val email = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.ADDRESS)) ?: ""
                        if (email.isNotBlank() && !emails.contains(email)) emails.add(email)
                    }
                }
            }
            result.success(mapOf("name" to displayName, "phones" to phones, "emails" to emails))
        } catch (error: Exception) {
            result.error("read_failed", "Unable to read selected contact.", error.message)
        }
    }
}