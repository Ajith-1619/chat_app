package com.skylink.slync

import android.app.Activity
import android.content.Intent
import android.provider.ContactsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val contactPickRequestCode = 4207
    private var pendingContactResult: MethodChannel.Result? = null

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
                else -> result.notImplemented()
            }
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
