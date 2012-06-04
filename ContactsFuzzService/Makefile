ALL: debug installd adb_forward run
debug:
	ant debug

installd:
	ant installd

run:
	adb shell am startservice -a 'tw.dm4.CONTACTSFUZZ' --es 'port' '7777'

adb_forward:
	adb forward tcp:7777 tcp:7777
