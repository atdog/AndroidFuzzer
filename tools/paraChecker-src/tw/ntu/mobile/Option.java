package tw.ntu.mobile;

import java.util.ArrayList;
import java.util.List;

import com.beust.jcommander.IStringConverter;
import com.beust.jcommander.Parameter;

public class Option {
	@Parameter
	List<String> parameters = new ArrayList<String>();

	@Parameter(names = {"-type1", "-1"}, description = "Real parameter type of the specify method ", required = true)
	String type1;

	@Parameter(names = {"-type2", "-2"}, description = "Parameter type to be checked whether be same as type1", required = true )
	String type2;
	
	@Parameter(names = {"-extjar", "-e"}, description = "External jar to import to check type")
	String jars = null;
}
