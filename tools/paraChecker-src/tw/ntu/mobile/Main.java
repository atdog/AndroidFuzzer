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
				"-1",
				"boolean",
				"-2",
				"java.lang.String",
				"-e",
				"/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/core/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/bouncycastle/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/ext/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/framework/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/android.policy/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/services/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/core-junit/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.commonctrl/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.framework/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.android.pimlib/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.android.easopen/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.scalado.util.ScaladoUtil/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.orange.authentication.simcard/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/android.supl/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/kafdex/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/CallRecorder/classes_dex2jar.jar:"
						+ "/Users/atdog/Desktop/myWork/CallRecorder",
		// "-e", "/Users/atdog/Desktop/myWork/tools/lib/android-4.0.3.jar:" +
		// "/Users/atdog/Desktop/myWork/CallRecorder",

		};
		Option option = new Option();
		JCommander jCommander = new JCommander(option);

		try {
			new JCommander(option, args);
		} catch (ParameterException e) {
			jCommander.usage();
			System.exit(0);
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
		System.out.println(inheritedCompare(option.type1, option.type2));
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

	static boolean inheritedCompare(String par1, String par2) {
		boolean result = false;
		if (par1.equals(par2) || par1.equals("java.lang.Class")) {
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
				} else if (par1.equals("boolean") && par2.equals("int")) {
					result = true;
				}
			}
		}
		return result;
	}
}