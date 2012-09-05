#!/bin/sh

[ ! -n "$1" ] && exit 0

###
#   Note: 
#       if there exist the exception
#           RuntimeException: "android.os.Parcelable" class not found
#       then please check whether the variable $SOOT_CLASSPATH is android-14
#       (api level must bigger than 10)   by  hcsu
###

#####
# Initialization
#####
APK_LOCATION=$1;
DIR_NAME=`echo $APK_LOCATION | sed -En 's/\.apk$//p'`
#SOOT_CLASSPATH="framework/core/classes_dex2jar.jar:framework/bouncycastle/classes_dex2jar.jar:framework/ext/classes_dex2jar.jar:framework/framework/classes_dex2jar.jar:framework/android.policy/classes_dex2jar.jar:framework/services/classes_dex2jar.jar:framework/core-junit/classes_dex2jar.jar:framework/com.htc.commonctrl/classes_dex2jar.jar:framework/com.htc.framework/classes_dex2jar.jar:framework/com.htc.android.pimlib/classes_dex2jar.jar:framework/com.htc.android.easopen/classes_dex2jar.jar:framework/com.scalado.util.ScaladoUtil/classes_dex2jar.jar:framework/com.orange.authentication.simcard/classes_dex2jar.jar:framework/android.supl/classes_dex2jar.jar:framework/kafdex/classes_dex2jar.jar:$DIR_NAME/classes_dex2jar.jar:"
SOOT_CLASSPATH="/Users/brucesu/android_sdk/platforms/android-14/android.jar"

#####
# Translate AndroidManifest file from binary to human readable
#####
#[ ! -f $APK_LOCATION ] && echo File not found. && exit
echo "[0;32m=====> Decode xml(you need install framework first)[0m"
tools/apktool d -f $APK_LOCATION $DIR_NAME
#
######
## unzip apk file
######
echo "[0;32m=====> unzip apk file[0m"
unzip -n $APK_LOCATION -d $DIR_NAME
#
######
## dex 2 jar
## Retrieve classes from the dex file
######
echo "[0;32m=====> dex2jar[0m"
tools/dex2jar-0.0.9.8/dex2jar.sh "$DIR_NAME/classes.dex" || (echo "[0;31m=====> Classes.dex not exist [0m" && exit)
(cd $DIR_NAME && jar xvf classes_dex2jar.jar)

#####
# Use soot.jar to generate dot files for rebuild the CFG
#####
echo "[0;32m=====> soot[0m"
java -jar tools/soot-2.5.0.jar -dump-cfg jb.uce -cp $SOOT_CLASSPATH:$DIR_NAME/classes_dex2jar.jar -process-path $DIR_NAME -d $DIR_NAME/sootOutput

