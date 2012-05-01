#!/bin/sh

[ ! -n "$1" ] && exit 0
[ ! -n "$2" ] && exit 0

CLASSPATH=$1
METHODNAME=$2
PARAS=`echo "$3" | sed 's/null/[^,]\*/g'`
if [ -d "$CLASSPATH" ]; then
    METHODFILENAME=`ls "$CLASSPATH" | grep "$METHODNAME" | grep -E "\\($PARAS\\)" || (printf 'ERROR' && exit) `
    ls "$CLASSPATH" | grep "$METHODNAME" 
    if [ -d "$CLASSPATH/$METHODFILENAME" ]; then
        FILENAME=`grep -lR "$METHODNAME" "$CLASSPATH/$METHODFILENAME"`
        printf "$FILENAME"
    else
        printf 'ERROR'
    fi
else 
    printf 'ERROR'
fi
