package ee.nekoko.nlpa2

import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

internal const val OMAPI_SESSION_CORRUPTED = "OMAPI_SESSION_CORRUPTED"

internal data class OmapiPoisonInfo(
        val readerName: String?,
        val reason: String,
        val operationMayHaveSucceeded: Boolean,
        val persistenceConfirmed: Boolean = true,
)

internal sealed class OmapiCleanupResult {
    data object Success : OmapiCleanupResult()

    data class RebootRequired(val info: OmapiPoisonInfo) : OmapiCleanupResult()
}

internal enum class OmapiHardwareEntry {
    INITIALIZE_SERVICE,
    LIST_READERS,
    CONNECT,
    OPEN_SESSION,
    OPEN_CHANNEL,
    TRANSMIT,
    RESET,
    DISCONNECT,
    CLEANUP,
}

/**
 * The deliberately forbidden methods make the Samsung workaround auditable and regression-testable.
 * Cleanup is only allowed to close individually tracked channels.
 */
internal interface OmapiCleanupBackend<C> {
    fun closeChannel(channel: C)

    fun closeSessionChannels(readerName: String)

    fun closeSession(readerName: String)

    fun closeReaderSessions(readerName: String)

    fun reconnectService()
}

internal class OmapiCleanupCoordinator<C>(
        private val backend: OmapiCleanupBackend<C>,
        private val readerKeys: () -> Set<String>,
        private val detachReader: (String) -> List<C>,
        private val clearAllLocalState: () -> Unit,
        private val poisonStore: OmapiPoisonStore,
        private val bootIdentityProvider: OmapiBootIdentityProvider,
        private val nowEpochMillis: () -> Long = System::currentTimeMillis,
) {
    private val cleanupLock = ReentrantLock()
    private val poison = AtomicReference<OmapiPoisonInfo?>(restorePersistedPoison())

    val poisonInfo: OmapiPoisonInfo?
        get() = poison.get()

    fun rejectionForHardwareEntry(entry: OmapiHardwareEntry): OmapiPoisonInfo? =
            when (entry) {
                OmapiHardwareEntry.INITIALIZE_SERVICE,
                OmapiHardwareEntry.LIST_READERS,
                OmapiHardwareEntry.CONNECT,
                OmapiHardwareEntry.OPEN_SESSION,
                OmapiHardwareEntry.OPEN_CHANNEL,
                OmapiHardwareEntry.TRANSMIT,
                OmapiHardwareEntry.RESET,
                OmapiHardwareEntry.DISCONNECT,
                OmapiHardwareEntry.CLEANUP -> poison.get()
            }

    fun cleanupReader(readerName: String): OmapiCleanupResult =
            cleanupLock.withLock {
                poison.get()?.let { return@withLock OmapiCleanupResult.RebootRequired(it) }
                cleanupReaderLocked(readerName)
            }

    fun cleanupAll(): OmapiCleanupResult =
            cleanupLock.withLock {
                poison.get()?.let { return@withLock OmapiCleanupResult.RebootRequired(it) }

                for (readerName in readerKeys()) {
                    val result = cleanupReaderLocked(readerName)
                    if (result is OmapiCleanupResult.RebootRequired) return@withLock result
                }
                OmapiCleanupResult.Success
            }

    fun markPoisoned(
            readerName: String?,
            reason: String,
            operationMayHaveSucceeded: Boolean,
    ): OmapiPoisonInfo =
            cleanupLock.withLock {
                val info = markPoisonedLocked(readerName, reason, operationMayHaveSucceeded)
                clearAllLocalState()
                info
            }

    private fun cleanupReaderLocked(readerName: String): OmapiCleanupResult {
        // Detach first so re-entrant work can never rediscover this Session or its Channels.
        val channels = detachReader(readerName)
        for (channel in channels) {
            try {
                backend.closeChannel(channel)
            } catch (e: Exception) {
                val info =
                        markPoisonedLocked(
                                readerName,
                                e.message ?: e.javaClass.simpleName,
                                operationMayHaveSucceeded = false,
                        )
                clearAllLocalState()
                return OmapiCleanupResult.RebootRequired(info)
            }
        }
        return OmapiCleanupResult.Success
    }

    private fun markPoisonedLocked(
            readerName: String?,
            reason: String,
            operationMayHaveSucceeded: Boolean,
    ): OmapiPoisonInfo {
        poison.get()?.let { return it }

        val candidate =
                OmapiPoisonInfo(
                        readerName = readerName,
                        reason = reason,
                        operationMayHaveSucceeded = operationMayHaveSucceeded,
                        persistenceConfirmed = false,
                )
        // Latch memory first. No later operation can pass the coordinator after this point.
        poison.set(candidate)
        val persisted =
                try {
                    poisonStore.save(
                            PersistedOmapiPoison(
                                    info = candidate,
                                    bootIdentity = bootIdentityProvider.currentBootIdentity(),
                                    recordedAtEpochMillis = nowEpochMillis(),
                            )
                    )
                } catch (_: Exception) {
                    false
                }
        val finalInfo = candidate.copy(persistenceConfirmed = persisted)
        poison.set(finalInfo)
        return finalInfo
    }

    private fun restorePersistedPoison(): OmapiPoisonInfo? {
        val persisted =
                try {
                    poisonStore.load()
                } catch (e: Exception) {
                    return OmapiPoisonInfo(
                            readerName = null,
                            reason =
                                    "Unable to verify persisted OMAPI safety state: " +
                                            (e.message ?: e.javaClass.simpleName),
                            operationMayHaveSucceeded = true,
                            persistenceConfirmed = false,
                    )
                }
                        ?: return null

        val currentIdentity =
                try {
                    bootIdentityProvider.currentBootIdentity()
                } catch (_: Exception) {
                    null
                }
        if (currentIdentity?.definitelyChangedSince(persisted.bootIdentity) == true) {
            val cleared =
                    try {
                        poisonStore.clear()
                    } catch (_: Exception) {
                        false
                    }
            if (cleared) return null
        }

        // Missing, incomparable, unchanged, or contradictory identity signals all fail closed.
        return persisted.info.copy(persistenceConfirmed = true)
    }
}
