
'''
Debugging monitor for Peach Agent.  Uses pydbgeng to monitor processes and
detect faults.  Would be nice to also eventually do other things like
"if we hit this method" or whatever.

@author: Michael Eddington
@version: $Id: debugger.py 2169 2010-10-20 00:55:34Z meddingt $
'''

#
# Copyright (c) Michael Eddington
#
# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights 
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
# copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in    
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Authors:
#   Michael Eddington (mike@phed.org)

# $Id: debugger.py 2169 2010-10-20 00:55:34Z meddingt $

import struct, sys, time
import subprocess
import re
import os
from Peach.agent import Monitor
from subprocess import *


class  FuzzIntentDataMonitor(Monitor):
    def __init__(self, args):
        '''
        Constructor.  Arguments are supplied via the Peach XML
        file.
        
        @type   args: Dictionary
        @param  args: Dictionary of parameters
        '''
        
        # Our name for this monitor
        self._name = None
        self._exception = {}
    
    def OnTestStarting(self):
        '''
        Called right before start of test case or variation
        '''
        self.clearlogcat()
        pass
    
    def OnTestFinished(self):
        '''
        Called right after a test case or varation
        '''
        pass
    
    def GetMonitorData(self):
        '''
        Get any monitored data from a test case.
        '''
        return self._exception
    
    def DetectedFault(self):
        '''
        Check if a fault was detected.
        '''
        return self.testfunction()

    def clearlogcat(self):
        command = ["adb", "logcat", "-c"]
        output = Popen(command, stdout=PIPE).communicate()[0]
        #os.system("adb logcat -c ")
    
    def testfunction(self):
        command = ["adb", "logcat", "-d", "-v", "time", "-s", "AndroidRuntime:E"]
        output = Popen(command, stdout=PIPE).communicate()[0]
        #output = os.popen("adb logcat -d -v time -s AndroidRuntime:E").read()
        result = re.search('AndroidRuntime', output)
        if result == None:
            #print 'no excpetion'
            return False
        else:
            self._exception['ExceptionStack'] = output;
            #print 'CRASH!'
            return True
    
    def OnFault(self):
        '''
        Called when a fault was detected.
        '''
        pass
    
    def OnShutdown(self):
        '''
        Called when Agent is shutting down, typically at end
        of a test run or when a Stop-Run occurs
        '''
        pass
    
    def StopRun(self):
        '''
        Return True to force test run to fail.  This
        should return True if an unrecoverable error
        occurs.
        '''
        return False
    
    def PublisherCall(self, method):
        '''
        Called when a call action is being performed.  Call
        actions are used to launch programs, this gives the
        monitor a chance to determin if it should be running
        the program under a debugger instead.
        
        Note: This is a bit of a hack to get this working
        '''
        pass

# end
