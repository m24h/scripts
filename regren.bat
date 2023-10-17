@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!perl
#line 15

local ($OLD,$NEW,$I,$T,$R,$A,$D);

sub getfiles($)
{
    my $dir=shift;
    my $f;
    my @file=();
    my @subdir;
    my $t;

    opendir ($f, $dir) || die "can't opendir $dir: $!\n";
    @subdir=grep { !/^\.$/ && !/^\.\.$/ } readdir($f);
    closedir $f;

    foreach $t(@subdir) {
        if (-d "$dir/$t") {
            push @file, getfiles("$dir/$t") if ($R);
            push @file, "$dir/$t" if ($D);
        } elsif (-f "$dir/$t") {
            push @file, "$dir/$t" unless ($D);
        }
    }

    return @file;
}

sub init()
{
	my $arg;
	while (defined($arg=shift @ARGV)) {
	    if (substr($arg,0,1) eq '-') {
	   		$T=1 if ($arg=~/t/);
	        $I=1 if ($arg=~/i/);
	        $R=1 if ($arg=~/r/);
	        $A=1 if ($arg=~/a/);
	       	$D=1 if ($arg=~/d/);
	    }  elsif (not defined $OLD) {
	        $OLD=$arg;
	    }  elsif (not defined $NEW) {
	        $NEW=$arg;
	    }
	}
	
	die "Usage: $0 [-itrd] <old file name to match> <new name to apply>\n rename files use regular express\n i:ignore case\n t:test only\n r:recur subdir\n d:change directory name only\n a:add number when conflicted\n"
		if (!defined($OLD) || !defined($NEW) || $OLD eq "")
}

sub ren($) 
{
	my $f=shift;
	my $d='';
	if ($f=~/^(.*[\\\/])([^\\\/]*)$/) {
		$d=$1 || '';
		$f=$2;
	}
	
	eval "\$f=~s/$OLD/$NEW/g".($I?'i':'').';';
    die "$@" if ($@);
	return $d.$f;
} 

sub addnum($$)
{
	my ($f,$i)=@_;
	$f=~s/(\.[^\\\/\.]*)?$/ ($i)$1/;
	return $f;
}

init();
my %chg;
my %all;
foreach (getfiles('.')) {
	$all{$_}='original in directory';
	my $d=ren($_);
	next if ($d eq $_);
	if (exists $all{$d}) {
		if ($A) {
			my $i=1;
			my $n;
			$i++ while (exists $all{addnum($d,$i)});
			$d=addnum($d,$i);
		} else {
			die "name conflicted when change '$_' -> '$d' ($all{$d})\n";
		}
	}
	$chg{$_}=$d;
	delete $all{$_};
	$all{$d}="renamed from '$_'";
}	
my $failed=0;
my $total=0;
foreach (keys %chg) {
    print "$_\n -> $chg{$_}\n";
    $total++;
    unless ($T) {
    	eval {$failed++ unless (rename $_,$chg{$_});};
        print "$@\n";
    } 
}
print STDERR "total:$total, failed:$failed\n"; 

exit 0;

__END__
:endofperl
