package ee.nekoko.nlpa2

import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

internal const val OMAPI_SESSION_CORRUPTED = "OMAPI_SESSION_CORRUPTED"

internal data class OmapiPoisonInfo(
        val readerName: String?,
        val reason: String,
        val operationMayHaveSucceeded: Boolean,
)

internal sealed class OmapiCleanupResult {
    data object Success : OmapiCleanupResult()

    data class RebootRequired(val info: OmapiPoisonInfo) : OmapiCleanupResult()
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
) {
    private val cleanupLock = ReentrantLock()
    private val poison = AtomicReference<OmapiPoisonInfo?>(null)

    val poisonInfo: OmapiPoisonInfo?
        get() = poison.get()

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
                val info =
                        poison.get()
                                ?: OmapiPoisonInfo(
                                                readerName,
                                                reason,
                                                operationMayHaveSucceeded,
                                        )
                poison.compareAndSet(null, info)
                clearAllLocalState()
                poison.get()!!
            }

    private fun cleanupReaderLocked(readerName: String): OmapiCleanupResult {
        // Detach first so re-entrant work can never rediscover this Session or its Channels.
        val channels = detachReader(readerName)
        for (channel in channels) {
            try {
                backend.closeChannel(channel)
            } catch (e: Exception) {
                val info =
                        OmapiPoisonInfo(
                                readerName,
                                e.message ?: e.javaClass.simpleName,
                                operationMayHaveSucceeded = false,
                        )
                poison.compareAndSet(null, info)
                clearAllLocalState()
                return OmapiCleanupResult.RebootRequired(poison.get()!!)
            }
        }
        return OmapiCleanupResult.Success
    }
}
