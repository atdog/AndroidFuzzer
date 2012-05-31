
ALL: debug installd insert
debug:
	ant debug

installd:
	ant installd

insert:
# 	adb shell am startservice -a 'tw.dm4.CONTACTSFUZZ' -e 'action' 'insert' -e 'display_name' 'atdog2' -e 'phone' '123'
	adb shell am startservice -a 'tw.dm4.CONTACTSFUZZ' -e 'action' 'insert' -e 'display_name' 'at\;do\\\\g\\xff2\\xFd'

update:
	adb shell am startservice -a 'tw.dm4.CONTACTSFUZZ' -e 'action' 'update' -e 'display_name' 'atdog' -e 'phone' '12345678'

exception:
	adb shell am startservice -a 'tw.dm4.CONTACTSFUZZ' -e 'action' 'exception'

