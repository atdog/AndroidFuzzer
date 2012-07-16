package ntu.mobile.test;

import com.jayway.android.robotium.solo.Solo;

import android.test.ActivityInstrumentationTestCase2;
import android.util.Log;

public class TestSolo extends ActivityInstrumentationTestCase2 {

	private static final String TARGET_PACKAGE_ID = "com.mywoo.clog";
	private static final String LAUNCHER_ACTIVITY_FULL_CLASSNAME = "com.mywoo.clog.Clog";

	private static Class<?> launcherActivityClass;
	static {
		try {
			launcherActivityClass = Class
					.forName(LAUNCHER_ACTIVITY_FULL_CLASSNAME);
		} catch (ClassNotFoundException e) {
			throw new RuntimeException(e);
		}
	}

	@SuppressWarnings("unchecked")
	public TestSolo() throws ClassNotFoundException {
		super(TARGET_PACKAGE_ID, launcherActivityClass);
	}

	private Solo solo;

	@Override
	protected void setUp() throws Exception {
		solo = new Solo(getInstrumentation(), getActivity());
	}

	public void testCanOpenSettings() {
		solo.clickOnView(getActivity().findViewById(2131165203));
	}

	@Override
	public void tearDown() throws Exception {
		solo.finishOpenedActivities();

	}
}
