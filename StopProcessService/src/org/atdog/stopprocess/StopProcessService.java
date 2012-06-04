package org.atdog.stopprocess;
import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;
import java.lang.reflect.Method;
import android.app.ActivityManager;


public class StopProcessService extends Service {

    public static final String LOG_TAG = "atdog";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(LOG_TAG, "onCreate");
    }
    @Override
    public IBinder onBind(Intent intent) {
        Log.d(LOG_TAG, "onBind");
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(LOG_TAG, "onStartCommand");
        String packageName = intent.getStringExtra("package"); 
        ActivityManager sd = (ActivityManager) this.getSystemService(ACTIVITY_SERVICE);
        try {
            Method method = Class.forName("android.app.ActivityManager").getDeclaredMethod("forceStopPackage", String.class);
            method.setAccessible(true);
            method.invoke(sd, packageName);
        } catch(Exception e) {
            Log.d(LOG_TAG, "Shit: error");
            e.printStackTrace();
        }
        return super.onStartCommand(intent, flags, startId);
    }
}
