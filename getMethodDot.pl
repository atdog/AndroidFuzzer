#!/usr/bin/perl

die "$0 dir_path method_name paras\n" if $#ARGV != 3;

my ($DIR_PATH, $METHOD_NAME, $PARAS, $EXTJAR) = @ARGV;
my @passParas = split ",", $PARAS;
my $is_found = 0;
my $FILE = "ERROR";

if( -d $DIR_PATH) {
    open my $COMMAND, "ls -1 '$DIR_PATH'| grep '$METHOD_NAME' |";
    while(<$COMMAND>) {
        my $method = $_;
        chomp $method;
        if($method =~ m/[^ ]* [^ ]*\((.*)\)/) {
            my @realParas = split ",", $1;
            if($#realParas == $#passParas) {
                $is_found = 1;
                for my $i (0..$#realParas) {
                    my $compareResult = `java -jar ./tools/paraChecker.jar -e $EXTJAR -1 $realParas[$i] -2 $passParas[$i]`;
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
