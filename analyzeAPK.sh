#!/bin/sh 

[ ! -n "$1" ] && exit 0

#####
# Initialization
#####
APK_LOCATION=$1;
DIR_NAME=`echo $APK_LOCATION | sed -En 's/\.apk$//p'`

#####
# unzip apk file
#####
echo "[0;32m=====> unzip apk file[0m"
rm -rf $DIR_NAME
mkdir -p $DIR_NAME
unzip $APK_LOCATION -d $DIR_NAME

#####
# Translate AndroidManifest file from binary to human readable
#####
echo "[0;32m=====> Get AndroidManifest[0m"
java -jar AXMLPrinter2.jar $DIR_NAME/AndroidManifest.xml > $DIR_NAME/AndroidManifest-real.xml

#####
# dex 2 jar
# Retrieve the classes from dex file
#####
echo "[0;32m=====> dex2jar[0m"
./dex2jar-0.0.9.8/dex2jar.sh $DIR_NAME/classes.dex || (echo "[0;31m=====> Classes.dex not exist [0m" && exit)
(cd $DIR_NAME && jar xvf classes_dex2jar.jar)

#####
# Use soot.jar to generate dot file for constructing CFG
#####
echo "[0;32m=====> soot[0m"
java -jar soot-2.5.0.jar -dump-cfg jb.uce -cp /System/Library/Frameworks/JavaVM.framework/Classes/classes.jar:../lib:$DIR_NAME -process-path $DIR_NAME -d $DIR_NAME/sootOutput

