#!/usr/bin/perl

use strict;

my $first = 1;
my $directory = '/var/cache/zabbix/domain.db';
my %hash = ();

open(FILE1, "/etc/zabbix/domain.list") || die "Error: $!\n";
opendir (DIR, $directory) or die $!;

print "{\n";
print "\t\"data\":[\n\n";

while (<FILE1>) {
                my $domain = substr($_, 0, -1);
                print ",\n" if not $first;
                $first = 0;

                print "\t{\n";
                print "\t\t\"{#DOMAIN}\":\"$domain\"\n";
                print "\t}";
		
		# Create domain database file if dosnt exist
		my $filename = "/var/cache/zabbix/domain.db/$domain";
		unless(-e $filename) {
			open my $fc, ">", $filename;
			close $fc;
		}
		$hash{ $domain } = $filename;
		
}

print "\n\t]\n";
print "}\n";

# check file list and delete old domains.

while (my $file = readdir(DIR)) {

        # Use a regular expression to ignore files beginning with a period or end ".tmp"
        next if ($file =~ m/^\./);
        next if ($file =~ m/\.tmp$/);


	if(exists($hash{$file})){
	}
	else{
		unlink "$directory/$file";
		unlink "$directory/$file.tmp";
		
	}
	

}

closedir(DIR);


