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

public class ContactsFuzzService extends Service {

    public static final String LOG_TAG = "dm4";

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

        String action = intent.getStringExtra("action");
        String display_name = intent.getStringExtra("display_name");
        String phone = intent.getStringExtra("phone");
        String unescape_name = unescapeString(display_name);

        if (action == null) {
            return START_STICKY;
        }

        if (action.equals("insert")) {
            Log.d(LOG_TAG, "insert");

            // new raw_contact_id
            ContentValues values = new ContentValues();
            values.clear();
            Uri rawContactUri = getContentResolver().insert(RawContacts.CONTENT_URI, values);
            long rawContactId = ContentUris.parseId(rawContactUri);

            if (display_name != null) {
                values.clear();
                values.put(Data.RAW_CONTACT_ID, rawContactId);
                values.put(Data.MIMETYPE, StructuredName.CONTENT_ITEM_TYPE);
                values.put(StructuredName.DISPLAY_NAME, unescape_name);
                getContentResolver().insert(Data.CONTENT_URI, values);
            }

            if (phone != null) {
                values.clear();
                values.put(Phone.RAW_CONTACT_ID, rawContactId);
                values.put(Data.MIMETYPE, Phone.CONTENT_ITEM_TYPE);
                values.put(Phone.NUMBER, phone);
                getContentResolver().insert(Data.CONTENT_URI, values);
            }

            // log
            Log.d(LOG_TAG, "RAW_CONTACT_ID: " + rawContactId);
            Log.d(LOG_TAG, "DISPLAY_NAME: " + unescape_name);
            Log.d(LOG_TAG, "NUMBER: " + phone);
        }
        else if (action.equals("update")) {
            Log.d(LOG_TAG, "update not implemented");
        }
        else if (action.equals("exception")) {
            String a = "abc";
            Integer.valueOf(a);
        }

        stopSelf();
        return super.onStartCommand(intent, flags, startId);
    }

    String unescapeString(String str) {
        String result = "";
        for (int i = 0; i < str.length(); i++) {
            char c = str.charAt(i);
            String tmp = "";
            if (c == '\\') {
                i++;
                c = str.charAt(i);
                if (c == '\\') {
                    tmp += "\\";
                }
                else if (c == 'x') {
                    String hex = "0x";
                    hex += str.substring(i + 1, i + 3);
                    i += 2;
                    int dec = Integer.decode(hex);
                    byte b = (byte)(dec & 0xff);
                    tmp += new String(new byte[] {b});
                }
                else {
                    Log.d(LOG_TAG, "not handle");
                }
            }
            else {
                tmp += c;
            }
            result += tmp;
        }
        return result;
    }
}
