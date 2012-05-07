#!/usr/bin/perl -w

use strict;
use ControlFlowGraph;
use ControlFlowNode;
use XML::Simple;
use Data::Dumper;

if($#ARGV != 0) {
    print "$0 path\n";
    exit;
}
my $RECORD_MODE = 0;
my $ANDROID_PATH = "/System/Library/Frameworks/JavaVM.framework/Classes/classes.jar:/Users/atdog/Desktop/myWork/tools/lib/android-4.0.3.jar";
my $JARPATH = "/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/core/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/bouncycastle/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/ext/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/framework/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/android.policy/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/services/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/core-junit/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.commonctrl/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.framework/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.android.pimlib/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.htc.android.easopen/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.scalado.util.ScaladoUtil/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/com.orange.authentication.simcard/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/android.supl/classes_dex2jar.jar:/Users/atdog/Desktop/myWork/tools/analyzeAPICall/framework/kafdex/classes_dex2jar.jar";
my ($APK_FILE_PATH) = @ARGV ;
my $PACKAGE;
my %APP_ENTRY_POINTS = (
    activity => [],
    service => [],
    receiver => [],
    provider => [],
);
my %PRIMITIVE_TYPE = (
    int => "I",
    byte => "B",
    short => "S",
    long => "J",
    float => "F",
    double => "D",
    boolean => "Z",
    char => "C"
);
my %JIMPLE_PRIMITIVE_TYPE = (
    i =>     "int",
    b =>     "int",
    l =>     "long",
    z =>     "boolean",
    f =>     "float",
);
my %PRIMITIVE_TYPE_RESOLVE = (
    I =>     "int",
    B =>     "byte",
    S =>     "short",
    J =>     "long",
    F =>     "float",
    D =>     "double",
    Z =>     "boolean",
    C =>     "char",
);
my %ENTRY_POINT = (
    activity => [{
            name => "onCreate",
            paras => "android.os.Bundle"
        }],
    service => [{
            name => "onStartCommand",
            paras => "android.content.Intent,int,int"
        },{
            name => "onBind",
            paras => "android.content.Intent"
        },{
            name => "onCreate",
            paras => ""
        }],
    receiver => [{
            name => "onReceive",
            paras => "android.content.Context,android.content.Intent" 
        }],
    provider => [{
            name => "onCreate",
            paras => ""
        }]
);
my %ALL_METHOD_CFG = ();
my %ALL_METHOD_TYPE = ();
my $DIR_PATH = $APK_FILE_PATH;
my $APK_FILE_NAME = $APK_FILE_PATH;
$DIR_PATH =~ s/\.apk//;
$APK_FILE_NAME =~ s/.*\/([^\/]*\.apk)/$1/;

Main();

sub getSourceFromAPK {
    my ($apkFilePath) = @_;
    system("./analyzeAPK.sh $apkFilePath");

}
sub parseAndroidManifest {
    my ($androidManifestXML) = @_;

    my $data = new XML::Simple->XMLin("$androidManifestXML");
    ###
    # assign global variable
    ###
    $PACKAGE = $data->{package};
    my $applications = $data->{application};
    ###
    #  I get the entry method first (for each component)
    ###
    for my $component (keys %APP_ENTRY_POINTS) {
        if (exists $applications->{$component}) {
            my $componentSet = $applications->{$component};
            my $reference = ref($componentSet);
            if($reference eq 'HASH') {
                push(@{$APP_ENTRY_POINTS{$component}}, {classname=>$componentSet->{'android:name'}});
                # record provider name
                if($component eq "provider") {
                    recordProviderNameToFile($componentSet->{'android:name'},$PACKAGE, $componentSet->{'android:authorities'});
                }
            }
            elsif($reference eq 'ARRAY'){
                ###
                #  each will be one of components
                ###
                my @cSet = @{$componentSet};
                for my $i (0..@cSet-1) {
                    my $eachComponent = $cSet[$i];
                    push(@{$APP_ENTRY_POINTS{$component}}, {classname=>$eachComponent->{'android:name'}}) ;
                    # record provider name
                    if($component eq "provider") {
                        recordProviderNameToFile($eachComponent->{'android:name'},$PACKAGE, $eachComponent->{'android:authorities'});
                    }
                }
            }
        }
    }
   #print Dumper(%APP_ENTRY_POINTS);
}

sub recordProviderNameToFile {
    ###
    #  preload app provider need to be recorded
    ###
    my ($providerName, $packageName, $authorities) = @_;
    if($RECORD_MODE == 0) {
        return;
    }
    open (my $providerNameFile,">> providerNameList.txt");
    my $checkData = `grep $providerName providerNameList.txt`;
    if ( ! ($checkData =~ m/^$providerName$/) ) {
        print $providerNameFile "Provider: $providerName\n";
        print $providerNameFile "    Package:     $packageName\n";
        print $providerNameFile "    Authorities: $authorities\n";
    }
    close $providerNameFile;
}

sub parseDotFileFromEntryPoint {
    for my $comName (keys %APP_ENTRY_POINTS) {
        for my $i (0..@{$APP_ENTRY_POINTS{$comName}}-1) {
            my $entryPoint = $APP_ENTRY_POINTS{$comName}[$i]->{classname};
            if($entryPoint =~ m/^\..*$/ ) {
                $entryPoint = "$PACKAGE$entryPoint";
            }
            elsif($entryPoint =~ m/^[^\.]*$/) {
                $entryPoint = "$PACKAGE.$entryPoint";
            }
            my $fileName;
            my $classPath;
            for my $j (0..@{$ENTRY_POINT{$comName}}-1) {
                $classPath = "$DIR_PATH/sootOutput/$entryPoint";
                if( not -d $classPath) {
                    print "-------------> [0;31m$classPath.$entryPoint not found[0m\n";
                    return;
                }
                $fileName = `./getMethodDot.pl '$classPath' '$ENTRY_POINT{$comName}[$j]->{name}' '$ENTRY_POINT{$comName}[$j]->{paras}' '$JARPATH'`;
                if($fileName !~ m/ERROR/) {
                    parseMethodDotFile($entryPoint, $ENTRY_POINT{$comName}[$j]->{name},$ENTRY_POINT{$comName}[$j]->{paras}, $fileName);
                }
                else {
                    print "-------------> [0;31m$classPath $ENTRY_POINT{$comName}[$j]->{name} not found[0m\n";
                }
            }
        }
    }
}
sub parseMethodDotFile {
    my ($entryPointClass, $entryPointMethod, $entryPointMethodParas, $dotFileName) = @_;
    ###
    # parse the full fileName
    ###
    my $methodCFG = {};
    my @nodeArray = ();
    print $dotFileName, "\n";
    open(my $FILE, "< $dotFileName");
    while(<$FILE>) {
        if($_ =~ m/label="(.*)";/) {
            my $node = new ControlFlowNode(-1,$1);
            $methodCFG->{_root} = $node;
            push(@{$node->{_prevNode}}, $node);
            $methodCFG = new ControlFlowGraph($dotFileName,$node);
            $ALL_METHOD_CFG{$dotFileName} = $methodCFG;
        }
        elsif($_ =~ m/.*\"(\d+)\"->\"(\d+)\".*/) {
            push(@{$nodeArray[$1]->{_nextNode}},$nodeArray[$2]);
            push(@{$nodeArray[$2]->{_prevNode}},$nodeArray[$1]);
        }
        elsif($_ =~ m/.*\"(\d+)\" \[.*label=\"(.*)\",\];/) {
            my $node = new ControlFlowNode($1,$2);
            my $nodeNum = $1;
            $nodeArray[$nodeNum]=$node;
            if($1 == 0) {
                push(@{$methodCFG->{_root}->{_nextNode}}, $nodeArray[$1]);
                push(@{$node->{_prevNode}}, $methodCFG->{_root});
            }
            my $statement = $2;
            print "[1;35m$statement[0m\n";
            ###
            #  find the invokation to the next method CFG
            ###
            if($statement =~ m/^(?:label\d+: )?(?:specialinvoke )?([^ ]*\(.*\))$/){ 
                my $invokation = $1;
                if($invokation =~ m/^(?:new )?([^\.]*)\.([^\.]*)\((.*)\)$/) {
                    my $parasOfInvokation = parseParas($methodCFG,$3,1);
                    my $subMethodFile = "";
                    my $classNameOfInvokation;
                    my $methodNameOfInvokation = $2;
                    if(exists $methodCFG->{_local}->{$1}) {
                        $classNameOfInvokation = $methodCFG->{_local}->{$1};
                    }
                    else {
                        $classNameOfInvokation = $1;
                    }
                    print "-=-=-=-> invokation: $classNameOfInvokation.$methodNameOfInvokation($parasOfInvokation)\n";
                    if($classNameOfInvokation =~ m/$PACKAGE/) {
                        $subMethodFile = `./getMethodDot.pl '$DIR_PATH/sootOutput/$classNameOfInvokation' '$methodNameOfInvokation' '$parasOfInvokation' '$JARPATH'`;
                        print "-=-=-=-> invoke file: $subMethodFile\n";
                        if($subMethodFile !~ /^ERROR$/) {
                            ####
                            # create sub method CFG
                            ####
                            parseMethodDotFile($classNameOfInvokation, $methodNameOfInvokation, $parasOfInvokation, $subMethodFile) if not exists $ALL_METHOD_CFG{$subMethodFile};
                            push(@{$ALL_METHOD_CFG{$subMethodFile}->{_prevNode}}, $nodeArray[$nodeNum]);
                            $nodeArray[$nodeNum]->{_subMethod} = $ALL_METHOD_CFG{$subMethodFile};
                            print "-=-=-=-> subMethod parsing done.\n";
                        }
                    }
                    else {
                        print "-=-=-=-> Dot file not exist.\n";
                    }
                }
            }
            ###
            #  need find the type of local vars
            #  need to discard array assignment
            ###
            elsif($statement =~ m/^(?:label\d+: )?([^\[\] ]*) :?= (.*)$/) {
                # r0 = this
                my $localVar = $1;
                my $varType = $2;
                if(exists $methodCFG->{_local}->{$varType}) {
                    $varType = $methodCFG->{_local}->{$varType};
                    print "-=-=-=-> Found in table: $varType\n";
                } else {
                    # rx = a.b.c    variable(or constant)
                    if($localVar =~ m/^(.*)\.([^.\(\)]*)$/) {
                        my $className = $1;
                        my $fieldName = $2;
                        if(exists $methodCFG->{_local}->{$className}) {
                            $className = $methodCFG->{_local}->{$className};
                        }
                        my $returnType = fieldChecker($className, $fieldName);
                        chomp($returnType);
                        $varType = $returnType;
                        print "-=-=-=-> className: $className\n";
                        print "-=-=-=-> fieldName: $fieldName\n";
                        print "-=-=-=-> returnType: $returnType\n";
                    }
                    # primitive data type
                    elsif($localVar =~ m/^(?:label\d+: )?\$?(f|l|b|i|z)\d+.*$/) {
                        $varType = $JIMPLE_PRIMITIVE_TYPE{$1};
                        print "-=-=-=-> primitive data type\n";
                        print "-=-=-=-> type: $varType\n";
                    }
                    elsif($localVar =~ m/^(?:label\d+: )?\$?(r)\d+.*$/) {
                        print "-=-=-=-> type: Class\n";
                        #if(exists $methodCFG->{_local}->{$varType}) {
                        #    $varType = $methodCFG->{_local}->{$varType};
                        #} else {
                        if($varType eq '@this') {
                           $varType = "$entryPointClass";
                           print "-=-=-=-> \@this: $varType\n";
                        }
                        # rx = @caughtexception
                        elsif($varType =~ m/\@caughtexception/) {
                            $varType = "java.lang.Throwable";
                            print "-=-=-=-> \@caughtexception: $varType\n";
                        }
                        # rx = @parameterX
                        elsif($varType =~ m/\@parameter(\d+)/) {
                            my $numOfPara = $1;
                            my ($parameter) = $dotFileName =~ m/.*\((.*)\)/;
                            for my $i (1..$numOfPara) {
                                $parameter =~ s/^[^,]*,(.*)$/$1/;
                            }
                            $parameter =~ s/^([^,]*),.*$/$1/;
                            $varType = toJimpleType($parameter);
                            print "-=-=-=-> \@parameter: $varType\n";
                        }
                        # rx = newarray (java.lang.String)[2]
                        elsif($varType =~ m/^newarray \((.*)\)\[.*\]$/) {
                            my $type = $1;
                            if($type =~ m/\./) {
                                $varType = "[L$type;";
                            }
                            else {
                                $varType = "[$PRIMITIVE_TYPE{$type}";
                            }
                            print "-=-=-=-> newarray: $varType\n";
                        }
                        # rx = rx[]
                        elsif($varType =~ m/^(.*)\[.*\]$/) {
                            if(exists $methodCFG->{_local}->{$1}) {
                                my $arrayType = $methodCFG->{_local}->{$1};
                                # [Lcom.android.htcdialer.util.SpeedDialUtils$SpeedDialEntry;'
                                if($arrayType =~ m/^\[(\[*L.*;)$/) {
                                    $varType = $1;
                                    if($varType =~ m/^L(.*);$/) {
                                        $varType = $1;
                                    }
                                }
                                elsif($arrayType =~ m/^\[(\[*.*)$/) {
                                    $varType = $1;
                                    if($varType =~ m/^[^\[]*$/) {
                                        $varType = $PRIMITIVE_TYPE_RESOLVE{$varType};
                                    }
                                }
                                else {
                                    $varType = "ArrayError";
                                }
                            }
                            else {
                                $varType = $1;
                            }
                            print "-=-=-=-> rx[]: $varType\n";
                        }
                        # rx = 0L 
                        #elsif($varType =~ m/^-?\d+L$/) {
                        #    $varType = "long"
                        #}
                        # rx = 1  or  rx = -1
                        #elsif($varType =~ m/^-?\d+$/) {
                        #    $varType = "int";
                        #}
                        # rx = + - 
                        #elsif($varType =~ m/^[^\(\)]* [+-\\*\/] [^\(\)]*$/) {
                        #    $varType = "int";
                        #}
                        # r1 instanceof a.b.c
                        # elsif($varType =~ m/.* instanceof .*/) {
                        #     $varType = "boolean";
                        # }
                        # rx = lengthof rx
                        #elsif($varType =~ m/^lengthof .*$/) {
                        #    $varType = "int";
                        #}
                        # rx = (Typecast) ry
                        elsif($varType =~ m/^\((.*)\) .*$/) {
                            $varType = toJimpleType($1);
                            print "-=-=-=-> Casting $varType\n";
                        }
                        # rx = \"string\"
                        elsif($varType =~ m/^\\"(.*)\\"$/) {
                            $varType = "java.lang.String";
                            print "-=-=-=-> \"string\": $varType\n";
                        }
                        # rx = new classname
                        elsif($varType =~ m/^new ([a-zA-Z0-9\.\$]*)$/) {
                            $varType = $1;
                            print "-=-=-=-> new: $varType\n";
                        }
                        # rx = a.b.c    variable(or constant)
                        elsif($varType =~ m/^(.*)\.([^.\(\)]*)$/) {
                            my $className = $1;
                            my $fieldName = $2;
                            if(exists $methodCFG->{_local}->{$className}) {
                                $className = $methodCFG->{_local}->{$className};
                            }
                            my $returnType = fieldChecker($className, $fieldName);
                            chomp($returnType);
                            $varType = $returnType;
                            print "-=-=-=-> className: $className\n";
                            print "-=-=-=-> fieldName: $fieldName\n";
                            print "-=-=-=-> returnType: $returnType\n";
                            $methodCFG->{_local}->{"$className.$fieldName"} = $returnType;
                            print "-=-=-=-> assign $className.$fieldName to $returnType\n"
                        }
                        # rx = rx.api()
                        elsif($varType =~ m/^(?:label\d+: )?(?:specialinvoke )?([^\(\)]*)\.([^\.\(\)]*)\((.*)\)$/) {
                            my $parentType = $1;
                            my $apiName = $2;
                            my $parameter = $3;
                            my $className;
                            print "-=-=-=-> Local var: $parentType\n";
                            if(exists $methodCFG->{_local}->{$parentType}) {
                                $className = $methodCFG->{_local}->{$parentType};
                            }
                            # rx = classname.api()
                            elsif($parentType =~ m/^[a-zA-Z0-9\.\$]*$/) {
                                    $className = $parentType;
                            }
                            # parse parameter
                            my $parasToCheck = parseParas($methodCFG,$parameter,0);
                            print "-=-=-=-> className: $className\n";
                            print "-=-=-=-> apiName: $apiName($parameter)\n";
                            # run typeChecker.jar
                            my $returnType;
                            if($parasToCheck eq "") {
                                $returnType = methodChecker($className, $apiName);
                                print "-=-=-=-> returnType: $returnType";
                            }
                            else {
                                print "-=-=-=-> parameter: $parasToCheck\n";
                                $returnType = methodChecker($className, $apiName, $parasToCheck);
                                print "-=-=-=-> returnType: $returnType";
                            }
                            chomp ($returnType);
                            if( $returnType !~ m/^NotFound-/) {
                                $varType = $returnType;
                            }
                        }
                            #}
                    }
                    else {
                        print "***** miss varType\n";
                    }
                }
                $methodCFG->{_local}->{$localVar} = $varType;
            }

            ###
        }
    }
    close $FILE;
    print "==== data ====" , "\n";
    #$methodCFG->dumpGraph;
    print Dumper($methodCFG->{_local});
}

sub toJimpleType {
    my ($parameter) = @_;
    my $varType;
    # int[]...
    if($parameter =~ m/^.*(\[\])+$/) {
        my $dimension = 0;
        my $array = $1;
        while($array =~ m/\[\]/) {
            $dimension++;
            $array =~ s/^\[\](.*)$/$1/;
        }
        $varType = "";
        for my $i (1..$dimension) {
            $varType = "${varType}[";
        }
        if($parameter =~ m/(int|byte|short|long|float|double|boolean|char)(?:\[\])+/) {
            $varType = "$varType$PRIMITIVE_TYPE{$1}";
        }
        # a.b.c[]...
        elsif($parameter =~ m/([\$a-zA-Z\.0-9]*)(?:\[\])+/) {
            $varType = "${varType}L$1;";
        }
    }
    # normal parameter
    else{ 
        $varType = $parameter;
    }
    return $varType;
}

sub parseParas{
    my ($methodCFG, $parameter, $toFileMode) = @_;
    my $parasToCheck = "";
    if($parameter ne "") {
        my @paras = split(/, /,$parameter);
        for my $para (@paras) {
            if(exists $methodCFG->{_local}->{$para}) {
                # to file mode: translate [Ljava.lang.String;  [I  -> java.lang.String[] int[]
                #print $methodCFG->{_local}->{$para},"\n";
                if($methodCFG->{_local}->{$para} =~ m/^(\[+)(.*)$/ && $toFileMode == 1) {
                    my $array = $1;
                    my $arrayType = $2;
                    my $dimension = "";
                    while($array =~ m/^\[+$/) {
                        $array =~ s/^\[(\[*)$/$1/;
                        $dimension .= "[]";
                    }
                    if($arrayType =~ m/^L([a-zA-Z0-9\$\.]*);$/ ) {
                        $parasToCheck="$parasToCheck,$1$dimension";
                    }
                    elsif($arrayType =~ m/^(I|B|S|J|F|D|Z|C)$/ ) {
                        $parasToCheck="$parasToCheck,$PRIMITIVE_TYPE_RESOLVE{$1}$dimension";
                    }
                }
                else {
                    $parasToCheck="$parasToCheck,$methodCFG->{_local}->{$para}";
                } 
            }
            elsif($para =~ m/^-?\d+$/) {
                $parasToCheck="$parasToCheck,int";
            }
            elsif($para =~ m/^-?\d+L$/) {
                $parasToCheck="$parasToCheck,long";
            }
            elsif($para =~ m/^\\".*\\"$/) {
                $parasToCheck="$parasToCheck,java.lang.String";
            }
            elsif($para eq "null") {
                $parasToCheck="$parasToCheck,null";
            }
            # new classname
            elsif($para =~ m/class \\"(.*)\\"/) {
                my $paraClass = $1;
                $paraClass =~ s/\//\./g;
                $parasToCheck="$parasToCheck,$paraClass";
            }
        }
        $parasToCheck =~ s/^,(.*)$/$1/;
    }
    return $parasToCheck;
}

sub methodChecker{
    my $c = $_[0];
    my $m = $_[1];
    my $p = defined $_[2] ? $_[2] : "";
    my $return;
    if(exists $ALL_METHOD_TYPE{"$c.$m($p)"}) {
        $return = $ALL_METHOD_TYPE{"$c.$m($p)"};
    }
    else {
        if($p ne "") {
            $return = `java -jar tools/typeChecker.jar -c '$c' -m '$m' -e '$JARPATH' -p '$p'`;
        } 
        else {
            $return =  `java -jar tools/typeChecker.jar -c '$c' -m '$m' -e '$JARPATH' `;
        }
        if($return =~ m/NotFound-JNI/ && defined $p) {
            $return = `java -jar tools/typeChecker.jar -c '$c' -m '$m' -e '$ANDROID_PATH' -p '$p'`;
        }
        elsif($return =~ m/NotFound-JNI/ && not defined $p){
            $return = `java -jar tools/typeChecker.jar -c '$c' -m '$m' -e '$ANDROID_PATH'`;
        }
    }
    return $return;
}
sub fieldChecker{
    my($c,$f) = @_;
    my $return;
    $return = `java -jar tools/typeChecker.jar -c '$c' -f '$f' -e '$JARPATH'`;
    if($return =~ m/NotFound-JNI/) {
        $return = `java -jar tools/typeChecker.jar -c '$c' -f '$f' -e '$ANDROID_PATH'`;
    }
    return $return;
}
sub Main{
    ######
    # use analyzeapk to retrieve the source file and java bytecode cfg dot file
    ######
    #getSourceFromAPK($APK_FILE_PATH);

    ######
    # parse AndroidManifest to find entry point for each component
    ######
    $JARPATH = "$JARPATH:$DIR_PATH/classes_dex2jar.jar";
    $ANDROID_PATH = "$ANDROID_PATH:$DIR_PATH/classes_dex2jar.jar";
    parseAndroidManifest("$DIR_PATH/AndroidManifest-real.xml");

    ######
    # parse each dot file of Method to CFG
    ######
    parseDotFileFromEntryPoint();

    #parseMethodDotFile('com.android.htcdialer.DialerService$WorkingHandler', 'updateContacts', '', '/Users/atdog/Desktop/evo/app/HtcDialer/sootOutput/com.android.htcdialer.DialerService$WorkingHandler/void updateContacts()/jb.uce-ExceptionalUnitGraph-0.dot');
    print Dumper(%ALL_METHOD_TYPE);
    print "-=-=-=-> All parsed files\n";
    for my $methodFile (keys %ALL_METHOD_CFG) {
        print "$methodFile\n";
    }
}
