package com.example.iptv_player

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import com.google.android.gms.cast.framework.CastContext

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            CastContext.getSharedInstance(applicationContext)
        } catch (e: Exception) {
            // Ignored if CastContext fails
        }
    }
}
