    package lab.mobile.ntu;
    
    import java.lang.reflect.Field;
    import java.lang.reflect.Method;
    import dalvik.system.DexClassLoader;
    import android.app.Service;
    import android.content.Intent;
    import android.os.IBinder;
    import android.util.Log;
    
    public class typeCheckerService extends Service {
        public static final String TYPE_CHECKER_ACTION = "lab.mobile.ntu.TYPE_CHECKER";
        public static final String LOG_TAG = "typeChecker";
        public static final String LOG_TAG_RESULT = "typeCheckerResult";
        String _appName;
        String _className;
        String _methodName;
        String _fieldName;
        String[] _parameters = {};
        boolean _found = false;
        String _returnType = "NotFound";
        ClassLoader classloader;
    
        @Override
        public IBinder onBind(Intent intent) {
            // TODO Auto-generated method stub
            Log.d(LOG_TAG, "onBind");
            return null;
        }
    
        @Override
        public void onCreate() {
            // TODO Auto-generated method stub
            Log.d(LOG_TAG, "------  onCreate    -------");
            classloader = this.getClassLoader();
            super.onCreate();
        }
    
        @Override
        public int onStartCommand(Intent intent, int flags, int startId) {
            // TODO Auto-generated method stub
            Log.d(LOG_TAG, "------onStartCommand-------");
            _returnType = "NotFound";
            _className = intent.getStringExtra("classname");
            _methodName = intent.getStringExtra("methodname");
            _fieldName = intent.getStringExtra("fieldname");
            _appName = intent.getStringExtra("appname");
            String paras = intent.getStringExtra("parameter");
            if (_appName != null) {
                Log.d(LOG_TAG, "appname: " + _appName);
            }
            if (_className != null) {
                Log.d(LOG_TAG, "classname: " + _className);
            }
            if (_methodName != null) {
                Log.d(LOG_TAG, "methodname: " + _methodName);
            }
            if (_fieldName != null) {
                Log.d(LOG_TAG, "fieldname: " + _fieldName);
            }
            if (paras != null) {
                Log.d(LOG_TAG, "parameter: " + paras);
                _parameters = paras.split(",");
            }
    
            Class<?> targetClass = classLoader();
    
            if (targetClass != null) {
                if (_methodName != null) {
                    inheritedMethod(targetClass);
                    if (!_found) {
                        _returnType = "NotFound-method";
                    }
                } else if (_fieldName != null) {
                    inheritedField(targetClass);
                    if (!_found) {
                        _returnType = "NotFound-field";
                    }
                }
            }
            Log.d(LOG_TAG_RESULT, _returnType);
            stopSelf();
            return super.onStartCommand(intent, flags, startId);
        }
    
        Class<?> classLoader() {
            Class<?> targetClass = null;
            
            try {
                if (_appName != null) {
                    DexClassLoader dexClassLoader = new DexClassLoader(_appName,
                            getDir("dex", 0).getAbsolutePath(), null, classloader);
                    targetClass = dexClassLoader.loadClass(_className);
                } 
                else {
                    targetClass = classloader.loadClass(_className);
                }
            } catch (ClassNotFoundException e) {
                // TODO Auto-generated catch block
                Log.d(LOG_TAG, "NotFound-class");
                return null;
            } catch (UnsatisfiedLinkError e) {
                Log.d(LOG_TAG, "NotFound-JNI error");
                return null;
            } catch (NoClassDefFoundError e) {
                Log.d(LOG_TAG, "NotFound-NoDef exception");
                return null;
            } catch (RuntimeException e) {
                Log.d(LOG_TAG, "NotFound-Runtime exception");
                return null;
            }
            return targetClass;
        }
    
        void inheritedMethod(Class<?> targetClass) {
            if (targetClass == null)
                return;
            Method[] allMethodInClass = targetClass.getDeclaredMethods();
            for (Method method : allMethodInClass) {
                String methodName = method.getName();
                if (methodName.equals(_methodName)) {
                    if (compareParameter(method.getParameterTypes(), _parameters)) {
                        _found = true;
                        _returnType = method.getReturnType().getName();
                        return;
                    }
                }
            }
            inheritedMethod(targetClass.getSuperclass());
        }
    
        void inheritedField(Class<?> targetClass) {
            if (targetClass == null)
                return;
            try {
                Field field = targetClass.getDeclaredField(_fieldName);
                _returnType = field.getType().getName();
                _found = true;
            } catch (Exception e) {
                // TODO Auto-generated catch block
                inheritedField(targetClass.getSuperclass());
            }
        }
    
        boolean compareParameter(Class<?>[] parameter1, String[] parameter2) {
            if (parameter1.length == parameter2.length) {
                for (int i = 0; i < parameter1.length; ++i) {
                    if (!inheritedCompare(parameter1[i], parameter2[i])) {
                        return false;
                    }
                }
                return true;
            } else {
                return false;
            }
        }
    
        boolean inheritedCompare(Class<?> par1, String par2) {
            boolean result = false;
            if (par1.getName().equals(par2)
                    || par1.getName().equals("java.lang.Class")) {
                result = true;
            } else {
                Class<?> superPar2;
                try {
                    superPar2 = Class.forName(par2).getSuperclass();
                    if (superPar2 != null) {
                        result = inheritedCompare(par1, superPar2.getName());
                    }
                } catch (ClassNotFoundException e) {
                    // TODO Auto-generated catch block
                    if (par2.equals("null")) {
                        result = true;
                    } else if (par1.getName().equals("boolean")
                            && par2.equals("int")) {
                        result = true;
                    }
                }
            }
            return result;
        }
    
    }

