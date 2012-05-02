package tw.ntu.mobile;

import java.util.ArrayList;
import java.util.List;

import com.beust.jcommander.IStringConverter;
import com.beust.jcommander.Parameter;

public class Option {
	@Parameter
	List<String> parameters = new ArrayList<String>();

	@Parameter(names = {"-classname", "-c"}, description = "Class name", required = true)
	String classname;

	@Parameter(names = {"-methodname", "-m"}, description = "Method name of the specific class" )
	String methodname = null;

	@Parameter(names = {"-parameter", "-p"}, description = "Method parameter")
	String paras = null;

	@Parameter(names = {"-extjar", "-e"}, description = "External jar to import to check type")
	String jars = null;
	
	@Parameter(names = {"-fieldname", "-f"}, description = "Field name of the specific class")
	String fieldname = null;
}
