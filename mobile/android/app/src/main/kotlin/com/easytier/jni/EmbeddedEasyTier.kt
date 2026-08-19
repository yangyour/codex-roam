package com.easytier.jni

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.util.concurrent.Executors

object EmbeddedEasyTier {
    private const val INSTANCE_NAME = "codex-roam"
    private const val POLL_INTERVAL_MS = 1500L
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var context: Context
    private var eventSink: EventChannel.EventSink? = null
    private var generation = 0
    private var phase = "idle"
    private var message = "内置网络尚未启动"
    private var ipv4: String? = null
    private var peers = 0
    private var vpnStartedFor: String? = null
    private var networkCidr = "10.126.126.0/24"

    fun attach(applicationContext: Context) {
        context = applicationContext
    }

    @Synchronized
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        sink?.success(status())
    }

    @Synchronized
    fun status(): Map<String, Any?> = mapOf(
        "phase" to phase,
        "message" to message,
        "ipv4" to ipv4,
        "peers" to peers,
    )

    @Synchronized
    fun start(settings: Map<String, Any?>): Map<String, Any?> {
        if (phase == "starting" || phase == "connected") return status()
        val config = try {
            buildConfig(settings)
        } catch (error: IllegalArgumentException) {
            update("error", "EasyTier 配置无效：${error.message}")
            return status()
        }
        generation += 1
        val runGeneration = generation
        update("starting", "正在启动内置 EasyTier")
        executor.execute {
            try {
                val parsed = EasyTierJNI.parseConfig(config)
                if (parsed != 0) throw IllegalStateException(EasyTierJNI.getLastError() ?: "配置无效")
                val started = EasyTierJNI.runNetworkInstance(config)
                if (started != 0) throw IllegalStateException(EasyTierJNI.getLastError() ?: "核心启动失败")
                mainHandler.post { poll(runGeneration) }
            } catch (error: Throwable) {
                update("error", "EasyTier 启动失败：${error.message ?: error.javaClass.simpleName}")
            }
        }
        return status()
    }

    @Synchronized
    fun stop(): Map<String, Any?> {
        generation += 1
        context.stopService(Intent(context, EmbeddedEasyTierVpnService::class.java))
        executor.execute { runCatching { EasyTierJNI.stopAllInstances() } }
        ipv4 = null
        peers = 0
        vpnStartedFor = null
        update("idle", "内置网络已停止")
        return status()
    }

    private fun poll(runGeneration: Int) {
        if (runGeneration != generation) return
        executor.execute {
            try {
                val json = EasyTierJNI.collectNetworkInfos(16)
                val info = parseInfo(json)
                if (info.error != null) {
                    update("error", "EasyTier：${info.error}")
                } else if (info.ipv4 == null) {
                    update("starting", "正在加入 EasyTier 私有网络")
                } else {
                    ipv4 = info.ipv4
                    peers = info.peers
                    startVpnIfNeeded(info.ipv4)
                    update("connected", "EasyTier 已连接 · ${info.peers} 个节点")
                }
            } catch (error: Throwable) {
                update("starting", "等待 EasyTier 网络就绪")
            } finally {
                mainHandler.postDelayed({ poll(runGeneration) }, POLL_INTERVAL_MS)
            }
        }
    }

    private fun parseInfo(raw: String?): NetworkInfo {
        if (raw.isNullOrBlank()) return NetworkInfo(null, 0, null)
        val root = JSONObject(raw)
        val map = root.optJSONObject("map") ?: root
        val info = map.optJSONObject(INSTANCE_NAME)
            ?: map.keys().asSequence().mapNotNull { map.optJSONObject(it) }.firstOrNull()
            ?: return NetworkInfo(null, 0, null)
        val error = info.optString("error_msg").takeIf { it.isNotBlank() }
        val inet = info.optJSONObject("my_node_info")?.optJSONObject("virtual_ipv4")
        val address = inet?.optJSONObject("address")?.optLong("addr")
        val prefix = inet?.optInt("network_length", 24) ?: 24
        val ip = address?.takeIf { it != 0L }?.let { value ->
            val unsigned = value and 0xffffffffL
            "${unsigned shr 24 and 255}.${unsigned shr 16 and 255}.${unsigned shr 8 and 255}.${unsigned and 255}/$prefix"
        }
        return NetworkInfo(ip, info.optJSONArray("routes")?.length() ?: 0, error)
    }

    @Synchronized
    private fun startVpnIfNeeded(address: String) {
        if (vpnStartedFor == address) return
        vpnStartedFor = address
        EmbeddedEasyTierVpnService.start(context, address, arrayListOf(networkCidr), INSTANCE_NAME)
    }

    private fun buildConfig(settings: Map<String, Any?>): String {
        val networkName = settings["networkName"]?.toString()?.trim().orEmpty()
        val networkSecret = settings["networkSecret"]?.toString().orEmpty()
        val peer = settings["peer"]?.toString()?.trim().orEmpty()
        val cidr = settings["networkCidr"]?.toString()?.trim().orEmpty()
        require(networkName.isNotEmpty()) { "缺少网络名称" }
        require(peer.isNotEmpty()) { "缺少公共节点地址" }
        require(cidr.matches(Regex("^(?:\\d{1,3}\\.){3}\\d{1,3}/\\d{1,2}$"))) {
            "无效网络 CIDR"
        }
        networkCidr = cidr
        return """
            instance_name = "$INSTANCE_NAME"
            hostname = "codex-roam"
            dhcp = true
            listeners = ["tcp://0.0.0.0:11010", "udp://0.0.0.0:11010"]

            [network_identity]
            network_name = "${tomlString(networkName)}"
            network_secret = "${tomlString(networkSecret)}"

            [[peer]]
            uri = "${tomlString(peer)}"

            [flags]
            mtu = 1380
            enable_ipv6 = false
            no_tun = false
            bind_device = true
        """.trimIndent()
    }

    private fun tomlString(value: String): String = value
        .replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\n", "\\n")
        .replace("\r", "\\r")

    @Synchronized
    private fun update(newPhase: String, newMessage: String) {
        phase = newPhase
        message = newMessage
        val snapshot = status()
        mainHandler.post { eventSink?.success(snapshot) }
    }

    fun onVpnError(error: String) {
        vpnStartedFor = null
        update("error", error)
    }

    private data class NetworkInfo(val ipv4: String?, val peers: Int, val error: String?)
}
