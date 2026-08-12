package ee.nekoko.nlpa2

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.*

class CertificatePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ee.nekoko.certificate_plugin")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getCertificateHashes") {
            try {
                val currentHashes = getHashes(getCurrentSignatures())
                val aramHashes = getHashes(getAramSignatures())

                result.success(
                        mapOf(
                                "sha256" to currentHashes.sha256,
                                "sha1" to currentHashes.sha1,
                                "aramSha256" to aramHashes.sha256,
                                "aramSha1" to aramHashes.sha1
                        )
                )
            } catch (e: Exception) {
                result.error("ERROR", e.message, null)
            }
        } else if (call.method == "getAbi") {
            try {
                result.success(Build.SUPPORTED_ABIS.toList())
            } catch (e: Exception) {
                result.error("ERROR", e.message, null)
            }
        } else {
            result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun getCurrentSignatures(): Array<Signature>? {
        val info =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    context.packageManager.getPackageInfo(
                            context.packageName,
                            PackageManager.GET_SIGNING_CERTIFICATES
                    )
                } else {
                    context.packageManager.getPackageInfo(
                            context.packageName,
                            PackageManager.GET_SIGNATURES
                    )
                }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            info.signatures
        }
    }

    @Suppress("DEPRECATION")
    private fun getAramSignatures(): Array<Signature>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return context.packageManager
                    .getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
                    .signatures
        }

        val signingInfo =
                context.packageManager
                        .getPackageInfo(
                                context.packageName,
                                PackageManager.GET_SIGNING_CERTIFICATES
                        )
                        .signingInfo ?: return null

        // Existing Android SecureElement releases authorize the oldest signer after a key
        // rotation, while newer native OMAPI releases authorize the current signer. Returning
        // the verified signing lineage lets the ARA-M page cover both implementations.
        return if (signingInfo.hasMultipleSigners()) {
            signingInfo.apkContentsSigners
        } else {
            signingInfo.signingCertificateHistory?.takeIf { it.isNotEmpty() }
                    ?: signingInfo.apkContentsSigners
        }
    }

    private fun getHashes(signatures: Array<Signature>?): CertificateHashes {
        val certificates = signatures.orEmpty().map { it.toByteArray() }
        return CertificateHashes(
                sha256 = certificates.map { getHash(it, "SHA-256") }.distinct(),
                sha1 = certificates.map { getHash(it, "SHA-1") }.distinct()
        )
    }

    private fun getHash(cert: ByteArray, algorithm: String): String {
        val md = MessageDigest.getInstance(algorithm)
        val digest = md.digest(cert)
        return digest.joinToString("") { "%02X".format(it) }
    }

    private data class CertificateHashes(val sha256: List<String>, val sha1: List<String>)
}
