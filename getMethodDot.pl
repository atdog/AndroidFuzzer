#!/usr/bin/perl

die "$0 dir_path method_name paras\n" if $#ARGV != 3;

my ($DIR_PATH, $METHOD_NAME, $PARAS, $EXTJAR) = @ARGV;
my @passParas = split ",", $PARAS;
my $is_found = 0;
my $FILE = "ERROR";
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

if( -d $DIR_PATH) {
    # special invoke
    # e.g. sendMessage(android.os.message)
    if($METHOD_NAME eq "sendMessage" && $PARAS eq "android.os.Message") {
        $METHOD_NAME = "handleMessage";
    }
    elsif($METHOD_NAME eq "sendMessageAtFrontOfQueue" && $PARAS eq "android.os.Message") {
        $METHOD_NAME = "handleMessage";
    }
    elsif($METHOD_NAME eq "sendMessageAtTime" && $PARAS eq "android.os.Message,long") {
        $METHOD_NAME = "handleMessage";
        @passParas = split ",", "android.os.Message";
    }
    elsif($METHOD_NAME eq "sendMessageDelayed" && $PARAS eq "android.os.Message,long") {
        $METHOD_NAME = "handleMessage";
        @passParas = split ",", "android.os.Message";
    }
    open my $COMMAND, "ls -1 '$DIR_PATH'| grep '$METHOD_NAME' |";
    while(<$COMMAND>) {
        my $method = $_;
        chomp $method;
        if($method =~ m/[^ ]* [^ ]*\((.*)\)/) {
            my @realParas = split ",", $1;
            if($#realParas == $#passParas) {
                $is_found = 1;
                for my $i (0..$#realParas) {
                    # change array
                    my $varType;
                    my $parameter = $realParas[$i];
                    if($varType =~ m/^.*(\[\])+$/) {
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
                            $parameter = "$PRIMITIVE_TYPE{$varType}$1";
                        }
                        # a.b.c[]...
                        elsif($parameter =~ m/([a-zA-Z\.0-9]*)(?:\[\])+/) {
                            $parameter = "${varType}L$1;";
                        }
                    }
                    my $compareResult = `java -jar ./tools/paraChecker.jar -e $EXTJAR -1 '$parameter' -2 '$passParas[$i]'`;
                    if($compareResult =~ m/false/) {
                        $is_found = 0;
                        break;
                    }
                    else { #true
                        $is_found = 1;
                    }
                }
                if($is_found) {
                    $FILE = `grep -lR '$METHOD_NAME' '$DIR_PATH/$method'`; 
                    chomp $FILE;
                    break;
                }
            }
        }
    }
    close $COMMAND;
}
print $FILE;
