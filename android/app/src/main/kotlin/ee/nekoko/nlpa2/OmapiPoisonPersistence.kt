package ee.nekoko.nlpa2

import android.content.Context
import android.provider.Settings
import java.io.File

internal data class OmapiBootIdentity(
        val bootCount: Long?,
        val kernelBootId: String?,
) {
    val isUsable: Boolean
        get() = bootCount != null || kernelBootId != null

    /** Returns true only when every comparable, reboot-scoped identifier changed. */
    fun definitelyChangedSince(previous: OmapiBootIdentity?): Boolean {
        if (previous == null) return false
        val comparisons =
                buildList {
                    if (bootCount != null && previous.bootCount != null) {
                        add(bootCount != previous.bootCount)
                    }
                    if (kernelBootId != null && previous.kernelBootId != null) {
                        add(kernelBootId != previous.kernelBootId)
                    }
                }
        return comparisons.isNotEmpty() && comparisons.all { it }
    }
}

internal data class PersistedOmapiPoison(
        val info: OmapiPoisonInfo,
        val bootIdentity: OmapiBootIdentity?,
        val recordedAtEpochMillis: Long,
)

internal interface OmapiPoisonStore {
    fun load(): PersistedOmapiPoison?

    /** Synchronous durability is required before local OMAPI references are detached. */
    fun save(poison: PersistedOmapiPoison): Boolean

    /** Returns false when durable removal could not be confirmed. */
    fun clear(): Boolean
}

internal fun interface OmapiBootIdentityProvider {
    fun currentBootIdentity(): OmapiBootIdentity?
}

internal class AndroidOmapiBootIdentityProvider(private val context: Context) :
        OmapiBootIdentityProvider {
    override fun currentBootIdentity(): OmapiBootIdentity? {
        val bootCount =
                try {
                    Settings.Global.getInt(
                                    context.contentResolver,
                                    Settings.Global.BOOT_COUNT,
                            )
                            .toLong()
                } catch (_: Exception) {
                    null
                }
        val kernelBootId =
                try {
                    File(KERNEL_BOOT_ID_PATH)
                            .readText()
                            .trim()
                            .lowercase()
                            .takeIf { BOOT_ID_PATTERN.matches(it) }
                } catch (_: Exception) {
                    null
                }
        return OmapiBootIdentity(bootCount, kernelBootId).takeIf { it.isUsable }
    }

    private companion object {
        private const val KERNEL_BOOT_ID_PATH = "/proc/sys/kernel/random/boot_id"
        private val BOOT_ID_PATTERN =
                Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
    }
}

internal class SharedPreferencesOmapiPoisonStore(context: Context) : OmapiPoisonStore {
    private val preferences =
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    override fun load(): PersistedOmapiPoison? {
        if (!preferences.getBoolean(KEY_PRESENT, false)) return null
        if (preferences.getInt(KEY_SCHEMA_VERSION, 0) != SCHEMA_VERSION) {
            return unreadablePersistedState("Unsupported persisted OMAPI poison schema")
        }

        val reason = preferences.getString(KEY_REASON, null)
        if (reason.isNullOrBlank()) {
            return unreadablePersistedState("Persisted OMAPI poison state is incomplete")
        }

        val bootCount =
                if (preferences.contains(KEY_BOOT_COUNT)) {
                    preferences.getLong(KEY_BOOT_COUNT, 0L)
                } else {
                    null
                }
        val kernelBootId = preferences.getString(KEY_KERNEL_BOOT_ID, null)
        val identity = OmapiBootIdentity(bootCount, kernelBootId).takeIf { it.isUsable }

        return PersistedOmapiPoison(
                info =
                        OmapiPoisonInfo(
                                readerName = preferences.getString(KEY_READER_NAME, null),
                                reason = reason,
                                operationMayHaveSucceeded =
                                        preferences.getBoolean(
                                                KEY_OPERATION_MAY_HAVE_SUCCEEDED,
                                                false,
                                        ),
                                persistenceConfirmed = true,
                        ),
                bootIdentity = identity,
                recordedAtEpochMillis = preferences.getLong(KEY_RECORDED_AT, 0L),
        )
    }

    override fun save(poison: PersistedOmapiPoison): Boolean {
        val editor =
                preferences.edit()
                        .clear()
                        .putInt(KEY_SCHEMA_VERSION, SCHEMA_VERSION)
                        .putBoolean(KEY_PRESENT, true)
                        .putString(KEY_READER_NAME, poison.info.readerName)
                        .putString(KEY_REASON, poison.info.reason)
                        .putBoolean(
                                KEY_OPERATION_MAY_HAVE_SUCCEEDED,
                                poison.info.operationMayHaveSucceeded,
                        )
                        .putLong(KEY_RECORDED_AT, poison.recordedAtEpochMillis)
        poison.bootIdentity?.bootCount?.let { editor.putLong(KEY_BOOT_COUNT, it) }
        poison.bootIdentity?.kernelBootId?.let { editor.putString(KEY_KERNEL_BOOT_ID, it) }
        return editor.commit()
    }

    override fun clear(): Boolean = preferences.edit().clear().commit()

    private fun unreadablePersistedState(reason: String): PersistedOmapiPoison =
            PersistedOmapiPoison(
                    info =
                            OmapiPoisonInfo(
                                    readerName = null,
                                    reason = reason,
                                    operationMayHaveSucceeded = true,
                                    persistenceConfirmed = true,
                            ),
                    bootIdentity = null,
                    recordedAtEpochMillis = preferences.getLong(KEY_RECORDED_AT, 0L),
            )

    private companion object {
        private const val PREFERENCES_NAME = "omapi_reboot_required"
        private const val SCHEMA_VERSION = 1
        private const val KEY_SCHEMA_VERSION = "schema_version"
        private const val KEY_PRESENT = "present"
        private const val KEY_READER_NAME = "reader_name"
        private const val KEY_REASON = "reason"
        private const val KEY_OPERATION_MAY_HAVE_SUCCEEDED = "operation_may_have_succeeded"
        private const val KEY_BOOT_COUNT = "boot_count"
        private const val KEY_KERNEL_BOOT_ID = "kernel_boot_id"
        private const val KEY_RECORDED_AT = "recorded_at_epoch_millis"
    }
}
