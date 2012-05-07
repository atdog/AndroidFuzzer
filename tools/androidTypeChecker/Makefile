ALL: debug reinstall run

debug:
	ant debug

uninstall:
	adb shell pm uninstall -k lab.mobile.ntu

install:
	adb install bin/androidTypeChecker-debug.apk

reinstall: debug uninstall install

run: reinstall
	adb shell am start -n lab.mobile.ntu/lab.mobile.ntu.typeCheckerActivity

service: 
	adb shell am startservice -a 'lab.mobile.ntu.TYPE_CHECKER' -e 'classname' 'com.android.htcdialer.DialerService' -e 'methodname' 'access\$100'
