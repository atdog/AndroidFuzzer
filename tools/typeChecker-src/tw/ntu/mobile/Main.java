package tw.ntu.mobile;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;

import javax.naming.CommunicationException;
import javax.naming.ldap.ExtendedRequest;

import org.junit.Assert;
import com.beust.jcommander.JCommander;
import com.beust.jcommander.ParameterException;

public class Main {
	public static void main(String[] args) {

//		String[] aStrings = {"-classname","android.util.Log","-methodname","d","-extjar" ,"/Users/atdog/Desktop/myWork/tools/lib/android-4.0.3.jar","-parameter", "java.lang.String,java.lang.String"};
		Option option = new Option();
		JCommander jCommander = new JCommander(option);

		try {
			new JCommander(option, args);
		} catch (ParameterException e) {
			jCommander.usage();
			System.exit(0);
		}

		String _className = option.classname;
		String _methodName = option.methodname;
		String[] _parameters = {};
		if (option.paras != null) {
			_parameters = option.paras.split(",");
		}
		String[] _extJar = {};
		if (option.jars != null) {
			_extJar = option.jars.split(",");
		}
		/*
		 * import external jar
		 */
		for(String jar : _extJar) {
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
		boolean _found = false;
		String _returnType = null;

		Class<?> targetClass = null;

		try {
			targetClass = Class.forName(_className);
		} catch (ClassNotFoundException e) {
			// TODO Auto-generated catch block
			System.out.println("NotFound-class");
			System.exit(0);
		}
		Method[] allMethodInClass = targetClass.getMethods();
		for (Method method : allMethodInClass) {
			String methodName = method.getName();
			if (methodName.equals(_methodName)) {
				if (compareParameter(method.getParameterTypes(), _parameters)) {
					_found = true;
					_returnType = method.getReturnType().getName();
					break;
				}
			}
		}
		if (_found) {
			System.out.println(_returnType);
		} else {
			System.out.println("NotFound-method");
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
				if (!parameter1[i].getName().equals(parameter2[i])) {
					return false;
				}
			}
			return true;
		} else {
			return false;
		}
	}
}
