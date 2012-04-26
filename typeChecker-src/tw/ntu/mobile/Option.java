package tw.ntu.mobile;

import java.util.ArrayList;
import java.util.List;

import com.beust.jcommander.IStringConverter;
import com.beust.jcommander.Parameter;

public class Option {
	@Parameter
	List<String> parameters = new ArrayList<String>();

	@Parameter(names = "-classname", description = "Class name", required = true)
	String classname;

	@Parameter(names = "-methodname", description = "Method name of the specific class", required = true)
	String methodname;

	@Parameter(names = "-parameter", description = "Method parameter")
	String paras = null;

	@Parameter(names = "-extjar", description = "External jar to import to check type")
	String jars = null;

}
