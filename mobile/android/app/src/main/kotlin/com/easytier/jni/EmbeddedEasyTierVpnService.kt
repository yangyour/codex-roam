package com.easytier.jni

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import app.codexroam.MainActivity
import app.codexroam.R
import kotlin.concurrent.thread

class EmbeddedEasyTierVpnService : VpnService() {
    companion object {
        private const val CHANNEL_ID = "easytier_network"
        private const val NOTIFICATION_ID = 126
        private const val IPV4 = "ipv4"
        private const val ROUTES = "routes"
        private const val INSTANCE = "instance"

        fun start(context: Context, ipv4: String, routes: ArrayList<String>, instanceName: String) {
            val intent = Intent(context, EmbeddedEasyTierVpnService::class.java).apply {
                putExtra(IPV4, ipv4)
                putStringArrayListExtra(ROUTES, routes)
                putExtra(INSTANCE, instanceName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("CodexRoam 私有网络已开启")
            .setContentText("EasyTier 正在保持远程连接")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val address = intent?.getStringExtra(IPV4)
        val instanceName = intent?.getStringExtra(INSTANCE)
        val routes = intent?.getStringArrayListExtra(ROUTES) ?: arrayListOf()
        if (address == null || instanceName == null) {
            stopSelf()
            return Service.START_NOT_STICKY
        }
        thread(name = "EasyTierVpnSetup") { setup(address, routes, instanceName) }
        return Service.START_STICKY
    }

    private fun setup(address: String, routes: List<String>, instanceName: String) {
        try {
            vpnInterface?.close()
            val (ip, prefix) = parseCidr(address)
            val builder = Builder()
                .setSession("Codex EasyTier")
                .setMtu(1380)
                .setBlocking(false)
                .addAddress(ip, prefix)
            routes.distinct().forEach { route ->
                val (routeIp, routePrefix) = parseCidr(route)
                builder.addRoute(routeIp, routePrefix)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) builder.setMetered(false)
            val established = builder.establish() ?: error("无法创建 Android VPN 接口")
            vpnInterface = established
            val result = EasyTierJNI.setTunFd(instanceName, established.fd)
            if (result != 0) error(EasyTierJNI.getLastError() ?: "无法连接 EasyTier TUN 接口")
        } catch (error: Throwable) {
            EmbeddedEasyTier.onVpnError("VPN 启动失败：${error.message ?: error.javaClass.simpleName}")
            stopSelf()
        }
    }

    private fun parseCidr(cidr: String): Pair<String, Int> {
        val parts = cidr.split('/', limit = 2)
        require(parts.size == 2) { "无效地址：$cidr" }
        return parts[0] to parts[1].toInt()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Codex 私有网络", NotificationManager.IMPORTANCE_LOW),
        )
    }

    override fun onDestroy() {
        vpnInterface?.close()
        vpnInterface = null
        super.onDestroy()
    }
}
