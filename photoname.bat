@REM ='
@perl -x -S %0 %*
@goto endofperl
@REM ';
#!perl
use Image::ExifTool qw(:Public);

die "Usage: photoname.pl <dir>\nrename .jpg files to YYYYMMDD-###-where-what [.jpg/tiff/tiff/dng/nef], sub-folders is included\n" if ($#ARGV<0);

sub getfiles($)
{
    my $dir=shift;
    my $F;
    my @file=();
    my @subdir;
    my $t;

    opendir ($F, $dir) || die "can't opendir $dir: $!";
    @subdir=grep { !/^\.$/ && !/^\.\.$/ } readdir($F);
    closedir $F;

    foreach $t(@subdir) {
        if (-d "$dir/$t") {
            push @file, getfiles("$dir/$t") ;
        }
        elsif ($t=~/\.(jpg)|(tif)|(tiff)|(dng)|(nef)$/i && -f "$dir/$t") {
            push @file, "$dir/$t";
        }
    }

    return @file;
}

local %NUM;
sub getindex($)
{
	my $d=shift;
	$NUM{$d}=0 unless exists($NUM{$d}); 
      $NUM{$d}=$NUM{$d}+1;
      return sprintf("%03d",$NUM{$d});	
}

my %newname;
my $t;
my $f;
my $exif;
foreach $f (getfiles($ARGV[0])) {
	if ($f=~/^(.*[\\\/])?(\d\d\d\d\d\d\d\d)\-(\d\d\d)\-(.*)(\.[^.]+)$/i) {
		$newname{$2.'-000000-'.$3.'-'.$f}=[$f,$1,$2,$4,lc($5)];
	} elsif ($f=~/^(.*[\\\/])?(\d\d\d\d)\D(\d\d)\D(\d\d)\D(\d\d)\D(\d\d)\D(\d\d)(.*)(\.[^.]+)$/i) {
		$newname{$2.$3.$4.'-'.$5.$6.$7.'-000-'.$f}=[$f,$1,$2.$3.$4,$8,lc($9)];
	} elsif ($f=~/^(.*[\\\/])?(.*)(\.[^.]+)$/i) {
		my ($t1,$t2,$t3)=($1,$2,$3);
		$exif=ImageInfo($f);
#		$t=$exif->{'GPSTimeStamp'};
#		if ($t=~/^(\d\d\d\d)\D(\d\d)\D(\d\d)\D(\d\d)\D(\d\d)\D(\d\d)\D*$/) {
#			$newname{$1.$2.$3.'-'.$4.$5.$6.'-000-'.$f}=[$f,$t1,$1.$2.$3,$t2,lc($t3)];
#			next;
#		}
		
		$t=$exif->{'DateTimeOriginal'};
		if ($t=~/^(\d\d\d\d)\D(\d\d)\D(\d\d)\D(\d\d)\D(\d\d)\D(\d\d)\D*$/) {
			$newname{$1.$2.$3.'-'.$4.$5.$6.'-000-'.$f}=[$f,$t1,$1.$2.$3,$t2,lc($t3)];
			next;
		} 
		
		print "can't get EXIF of $f\n";
	}  else {
		print "bad $f\n";
	}
}	

for my $k(sort keys %newname) {
	$t=$newname{$k};
	$f=$t->[1].$t->[2].'-'.getindex($t->[2]).'-'.$t->[3].$t->[4];
	next if (lc($f) eq lc($t->[0]));
	print ($t->[0],'->',$f,"\n");
	if (-f $f) {
    	print "File name exists: $f\n";
    }
    else {
        eval {rename $t->[0],$f;};
        print "$@\n";
    }
}

__END__
:endofperl