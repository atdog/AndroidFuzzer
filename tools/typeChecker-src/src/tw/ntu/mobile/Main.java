package tw.ntu.mobile;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import com.beust.jcommander.JCommander;
import com.beust.jcommander.ParameterException;

public class Main {
	static String _className;
	static String _methodName;
	static String _fieldName;
	static String[] _parameters = {};
	static String[] _extJar = {};
	static boolean _found = false;
	static String _returnType = "NotFound";

	public static void main(String[] args) {

		String[] aStrings = {
				"-c","mobile.lab.PhoneCallDetect.PhoneListActivity",
				"-m","registerForContextMenu",
				"-p","android.widget.ListView",
				"-e",	"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/core/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/bouncycastle/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/ext/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/framework/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/android.policy/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/services/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/core-junit/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.commonctrl/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.framework/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.android.pimlib/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.android.easopen/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.scalado.util.ScaladoUtil/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.orange.authentication.simcard/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/android.supl/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/kafdex/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/CallRecorder/classes_dex2jar.jar:" +
						"/Users/atdog/Desktop/myWork/CallRecorder",
//				"-e",   "/Users/atdog/Desktop/myWork/tools/lib/android-4.0.3.jar:" +
//						"/Users/atdog/Desktop/myWork/CallRecorder",
						
				};
		Option option = new Option();
		JCommander jCommander = new JCommander(option);

		try {
			new JCommander(option, aStrings);
		} catch (ParameterException e) {
			jCommander.usage();
			System.exit(0);
		}

		if ((option.methodname == null && option.fieldname == null)
				|| (option.methodname != null && option.fieldname != null)) {
			jCommander.usage();
			System.exit(0);
		}

		_className = option.classname;
		_methodName = option.methodname;
		_fieldName = option.fieldname;
		if (option.paras != null) {
			_parameters = option.paras.split(",");
		}
		if (option.jars != null) {
			_extJar = option.jars.split(":");
		}
		/*
		 * import external jar
		 */
		for (String jar : _extJar) {
			try {
				addFile(jar);
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
		/*
		 * start type check
		 */
		Class<?> targetClass = classLoader();

		if (option.methodname != null) {
			inheritedMethod(targetClass);
			if (!_found) {
				_returnType = "NotFound-method";
			}
		}
		else if (option.fieldname != null) {
			inheritedField(targetClass);
			if (!_found) {
				_returnType = "NotFound-field";
			}
		}
		System.out.println(_returnType);
	}

	private static Class<?> classLoader() {
		Class<?> targetClass = null;
		
		try {
			targetClass = Class.forName(_className);
		} catch (ClassNotFoundException e) {
			// TODO Auto-generated catch block
			System.out.println("NotFound-class");
			System.exit(0);
		} catch(UnsatisfiedLinkError e) {
			System.out.println("NotFound-JNI error");
//			try {
//				addFile(_androidJar);
//			} catch (Exception e1) {
//				// TODO Auto-generated catch block
//				e1.printStackTrace();
//			}
//			return classLoader();
			System.exit(0);
		} catch(RuntimeException e) {
			System.out.println("NotFound-Runtime exception");
			System.exit(0);
		}
		return targetClass;
	}
	
	private static void inheritedMethod(Class<?> targetClass) {
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

	private static void inheritedField(Class<?> targetClass) {
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

	private static final Class[] parameters = new Class[] { URL.class };

	public static void addFile(String s) throws IOException {
		File f = new File(s);
		addFile(f);
	}

	@SuppressWarnings("deprecation")
	public static void addFile(File f) throws IOException {
		// f.toURL is deprecated
		addURL(f.toURL());
	}

	public static void addURL(URL u) throws IOException {
		URLClassLoader sysloader = (URLClassLoader) ClassLoader
				.getSystemClassLoader();
		Class<URLClassLoader> sysclass = URLClassLoader.class;

		try {
			Method method = sysclass.getDeclaredMethod("addURL", parameters);
			method.setAccessible(true);
			method.invoke(sysloader, new Object[] { u });
		} catch (Throwable t) {
			t.printStackTrace();
			throw new IOException(
					"Error, could not add URL to system classloader");
		}

	}

	static boolean compareParameter(Class<?>[] parameter1, String[] parameter2) {
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

	static boolean inheritedCompare(Class<?> par1, String par2) {
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
				}
				else if(par1.getName().equals("boolean") && par2.equals("int")) {
					result = true;
				}
			}
		}
		return result;
	}
    static native int registerNatives();
}
