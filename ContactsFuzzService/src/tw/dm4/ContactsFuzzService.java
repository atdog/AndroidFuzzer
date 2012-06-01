package tw.dm4;
import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.content.ContentValues;
//import android.provider.ContactsContract.CommonDataKinds.*;
import android.provider.ContactsContract.CommonDataKinds.Phone;
import android.provider.ContactsContract.CommonDataKinds.StructuredName;
import android.provider.ContactsContract.RawContacts;
import android.provider.ContactsContract.Data;
import android.content.ContentUris;
import android.net.Uri;
import android.util.Log;
import java.net.ServerSocket;
import java.net.Socket;
import java.io.IOException;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.lang.Thread;

public class ContactsFuzzService extends Service {

    public static final String LOG_TAG = "dm4";
    public static ServerSocket serverSocket;
    public final int serverPort = 7777;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(LOG_TAG, "onCreate");
        openSocket();
    }

    void openSocket() {
        Log.d(LOG_TAG, "openSocket");
        try {
            serverSocket = new ServerSocket(serverPort);
            serverSocket.setReuseAddress(true);
        }
        catch(IOException e) {
            serverSocket = null;
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        Log.d(LOG_TAG, "onBind");
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(LOG_TAG, "onStartCommand");

        new Thread(new Runnable() {
            public void run() {
                if(serverSocket != null) { 
                    try {
                        String line = "";
                        while(!line.equals("androidFuzzerDead")) {
                            Socket newSocket = serverSocket.accept();
                            BufferedReader in = new BufferedReader(new InputStreamReader(newSocket.getInputStream()));
                            BufferedWriter out = new BufferedWriter(new OutputStreamWriter(newSocket.getOutputStream()));
                            line = in.readLine();
                            Log.d(LOG_TAG,"read: "+line);
                            fuzzTable(line);
                            out.newLine();
                            newSocket.close();
                        }
                        serverSocket.close();
                    } catch(IOException e) {
                        Log.d(LOG_TAG,"catch exception");
                    }
                }
            }
        }).start();


        stopSelf();
        Log.d(LOG_TAG, "stopSelf");
        return super.onStartCommand(intent, flags, startId);
    }
    @Override
    public void onDestroy (){
        Log.d(LOG_TAG, "onDestroy");
    }

    public void fuzzTable(String display_name) {
        String unescape_name = unescapeString(display_name);

        // new raw_contact_id
        ContentValues values = new ContentValues();
        Uri rawContactUri = getContentResolver().insert(RawContacts.CONTENT_URI, values);
        long rawContactId = ContentUris.parseId(rawContactUri);

        values.put(Data.RAW_CONTACT_ID, rawContactId);
        values.put(Data.MIMETYPE, StructuredName.CONTENT_ITEM_TYPE);
        values.put(StructuredName.DISPLAY_NAME, unescape_name);
        getContentResolver().insert(Data.CONTENT_URI, values);

        // log
        Log.d(LOG_TAG, "RAW_CONTACT_ID: " + rawContactId);
        Log.d(LOG_TAG, "DISPLAY_NAME: " + unescape_name);
    }

    String unescapeString(String str) {
        int bufLen = str.length() / 4;
        byte[] byteAry = new byte[bufLen];
        for (int i = 0; i < bufLen; i++) {
            String hex = "0";
            hex += str.substring(i * 4 + 1, i * 4 + 4);
            int dec = Integer.decode(hex);
            byte b = (byte)(dec & 0xff);
            byteAry[i] = b;
        }
        return new String(byteAry);
    }
}
