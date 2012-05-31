#!/bin/sh

#[ ! -n "$1" ] && exit 0

#####
# Initialization
#####
APK_LOCATION=$1;
DIR_NAME=`echo $APK_LOCATION | sed -En 's/\.apk$//p'`	

#modified to your phone's framework path
FRAMEWORKS_ODEX="framework/*.odex"
BOOTCLASSPATH="framework" 
SOOT_CLASSPATH=""

process_framework()
{
	#####
	# transform odex to dex 
	#####
	echo "[0;32m=====> transform odex to dex[0m"
	java -jar tools/baksmali-1.3.2.jar -x $1.odex -d $BOOTCLASSPATH
	java -Xmx512M -jar tools/smali-1.3.2.jar out -o classes.dex
	mv classes.dex $1/

	#####
	# dex 2 jar
	# Retrieve the classes from dex file
	#####
	echo "[0;32m=====> dex2jar[0m"
	tools/dex2jar-0.0.9.8/dex2jar.sh $1/classes.dex || (echo "[0;31m=====> $1/Classes.dex not exist [0m" && exit)
	rm -rf out #prevent "method index is too large"
}
####
# Preprocess framework
####
echo "[0;32m=====>converting framework odex to jar [0m"
for f in $FRAMEWORKS_ODEX
do
	dir=`echo $f | sed -En 's/\.odex$//p'`
	if [ ! -d $dir ]
	then
		mkdir $dir
	fi
	if [ ! -f $dir/classes_dex2jar.jar ]
	then
		process_framework $dir 
	fi
	SOOT_CLASSPATH="$SOOT_CLASSPATH:$dir/classes_dex2jar.jar"
done

#####
# Translate AndroidManifest file from binary to human readable
#####
[ ! -f $APK_LOCATION ] && echo File not found. && exit
echo "[0;32m=====> Decode xml(you need install framework first)[0m"
tools/apktool d -f $APK_LOCATION $DIR_NAME

#####
# unzip apk file
#####
echo "[0;32m=====> unzip apk file[0m"
unzip -n $APK_LOCATION -d $DIR_NAME

#####
# transform odex to dex 
#####
echo "[0;32m=====> transform odex to dex[0m"
java -jar tools/baksmali-1.3.2.jar -x $DIR_NAME.odex -d $BOOTCLASSPATH
java -Xmx512M -jar tools/smali-1.3.2.jar out -o classes.dex
mv classes.dex $DIR_NAME/

#####
# dex 2 jar
# Retrieve the classes from dex file
#####
echo "[0;32m=====> dex2jar[0m"
tools/dex2jar-0.0.9.8/dex2jar.sh $DIR_NAME/classes.dex || (echo "[0;31m=====> $DIR_NAME/Classes.dex not exist [0m" && exit)
(cd $DIR_NAME && jar xvf classes_dex2jar.jar)
rm -rf out #prevent "method index is too large."

#####
# Use soot.jar to generate dot file for constructing CFG
#####
echo "[0;32m=====> soot[0m"
java -jar tools/soot-2.5.0.jar -dump-cfg jb.uce -cp $SOOT_CLASSPATH -process-path $DIR_NAME -d $DIR_NAME/sootOutput

