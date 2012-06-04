ALL: debug sign installd run
debug:
	ant debug

installd:
	adb uninstall "org.atdog.stopprocess"
	adb install bin/StopProcessService-signed.apk

run:
	adb shell am startservice -a 'org.atdog.stopprocess.KILL'

sign:
	java -jar ../signKey/signapk.jar ../signKey/platform.x509.pem ../signKey/platform.pk8 bin/StopProcessService-debug.apk bin/StopProcessService-signed.apk
