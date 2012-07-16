#!/bin/sh

adb shell am instrument -w -e class ntu.mobile.test.TestSolo ntu.mobile.test/android.test.InstrumentationTestRunner
