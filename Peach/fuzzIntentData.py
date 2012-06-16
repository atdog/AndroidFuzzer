
'''
Some default file publishers.  Output generated data to a file, etc.

@author: Michael Eddington
@version: $Id: file.py 2055 2010-04-27 01:20:26Z meddingt $
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

# $Id: file.py 2055 2010-04-27 01:20:26Z meddingt $

import os, sys, time
from Peach.Engine.engine import Engine
from Peach.publisher import Publisher
import base64
import re
from socket import *

try:
    import win32pdh
    import win32pdhutil
    import win32pdhquery
    import ctypes
    import win32api
except:
    pass

class FuzzIntentData(Publisher):
    '''
    Publishes generated data to a file.  No concept of receaving data
    yet.
    '''

    def __init__(self, filename, package, activity, port, device):
        '''
        @type   filename: string
        @param  filename: Filename to write to
        '''
        Publisher.__init__(self)
        self._filename = None
        self._fd = None
        self._state = 0 # 0 -stoped; 1 -started
        self._package = package
        self._activity = activity
        self._port = int(port)
        self._device = device
        self.setFilename(filename)
        # initial fuzztableService
        os.system("adb -s "+device+" shell am startservice -a 'tw.dm4.CONTACTSFUZZ' --es 'port' '"+port+"'")
        os.system("adb -s "+device+" forward tcp:"+port+" tcp:"+port)

    def getFilename(self):
        '''
        Get current filename.

        @rtype: string
        @return: current filename
        '''
        return self._filename
    def setFilename(self, filename):
        '''
        Set new filename.

        @type filename: string
        @param filename: Filename to set
        '''
        self._filename = filename

    def start(self):
        pass

    def connect(self):
        if self._state == 1:
            raise Exception('File::start(): Already started!')

        if self._fd != None:
            self._fd.close()

        self.mkdir()

        self._fd = open(self._filename, "w+b")
        self._state = 1

    def stop(self):
        self.close()

    def mkdir(self):
        # lets try and create the folder this file lives in
        delim = ""

        if self._filename.find("\\") != -1:
            delim = '\\'
        elif self._filename.find("/") != -1:
            delim = '/'
        else:
            return

        # strip filename
        try:
            path = self._filename[: self._filename.rfind(delim) ]
            os.mkdir(path)
        except:
            pass

    def close(self):
        if self._state == 0:
            return

        self._fd.close()
        self._fd = None
        self._state = 0

    def send(self, data):
        if type(data) != str:
            data = data.encode('iso-8859-1')
        print data
        #self._fd.write(data)

    def receive(self, size = None):
        if size != None:
            return self._fd.read(size)

        return self._fd.read()
    def call(self, method, args):
        # write data
        fuzz_string = re.sub(r'([a-zA-Z0-9]{2})', r'\\x\1', args[0].encode('hex'))
        host = '127.0.0.1'
        port = self._port
        s = socket(AF_INET, SOCK_STREAM)
        s.connect((host, port))
        s.send(fuzz_string + "\n")
        s.makefile().readline()
        s.close()
        print fuzz_string
        print args
        PACKAGE = self._package
        ACTIVITY = self._activity
        # kill process first
        os.system('adb -s '+self._device+' shell am startservice -a "org.atdog.stopprocess.KILL" --es "package" "'+ PACKAGE +'"')
        # monkey runner is used to start activity
        #os.system("monkeyrunner executeApp.py " + PACKAGE +" " + ACTIVITY);
        print 'adb -s '+self._device+' shell am start -n ' + PACKAGE + "/" + ACTIVITY
        os.system('adb -s '+self._device+' shell am start -W -n ' + PACKAGE + "/" + ACTIVITY + " -a android.intent.action.MAIN")
# end
