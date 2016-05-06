#!/usr/bin/perl -w
use strict;
use Carp;

# Cisco bulk command script - web0 2014

# This can be used with a bash loop to apply updates to a list of devices
# See webster for lots of examples of how this can and has been used

# Commands and syntax vary depending on device and IOS version
# To overcome this I've typically used rancid or other config files to grep for 
# a specific target device and built out the commands in text files for each
# Don't forget to write memory

# Requires the Net::Telnet::Cisco cpan module which can be installed
# with 'sudo cpan Net::Telnet::Cisco' or with cpanminus

use Getopt::Std;
use Net::Telnet::Cisco;
our($opt_c,$opt_e,$opt_f,$opt_h,$opt_n,$opt_o,$opt_p,$opt_u,$opt_v);
getopt('cfhnopu');

################################################
############# Main Editable Variables
my $username = $opt_u || 'spectrum';
my $password = $opt_p || '';
my $enablepw = $opt_n || '';
############# Additional Options
my $timeout = '5'; # Login timeout
################################################


################################################
# Command line option checking for errors and requirements
################################################
unless($opt_h){print_usage('h');} # Did we get a hostname?
unless($opt_c||$opt_f){print_usage('c');} # Did we get a command or file?
if($opt_c && $opt_f){print_usage('c');} # Did someone try to do both a file and command?
if(grep(/-e/,@ARGV)){$opt_e = 1;}
if(grep(/-v/,@ARGV)){$opt_v = 1;}
################################################

################################################
# Varibles you shouldn't touch
################################################
my $hostname = $opt_h; # Make this easier to read
my $cmdfile = $opt_f;  # this too
my $outputlog = $opt_o;  # and this
my $verbose = $opt_v;
################################################

################################################
# Get our desired commands
################################################
my @commands;
if($cmdfile){ # From the file
	if(!-r $cmdfile ){ # Make sure we read the file and it exists
		print "Unable to read file $cmdfile\n";
		exit 1;
	}
	open(CMDFILE, "<", "$cmdfile") or croak "Couldn't open file $cmdfile - $!";
	while (<CMDFILE>){
		chomp;
		push(@commands,$_);
	}
	close(CMDFILE);
}
if($opt_c){
	#push(@commands,$opt_c);
	@commands = split(';',$opt_c);
}
################################################

################################################
# Cisco connection stuff
################################################
# Setup logging
my $logfh;
my $logbuffer;
my $bufferfh;
my $date = qx/date/;
open($bufferfh, ">>", \$logbuffer) or die $!;
if($outputlog){
    if(!-w $outputlog && -e $outputlog){
		print "Unable to write to log file $outputlog\n";
		exit 1;
	}
	open($logfh, ">>", $outputlog) or die $!;
}
if($logfh){ print $logfh "\n## Attempting to login to $hostname at $date\n";}
my $session = Net::Telnet::Cisco->new(Host => $hostname, Input_log => $bufferfh);

print "\nAttempting to login to $hostname\n";
# Login 
$session->login(	Name		=>	$username,
					Password	=>	$password,
					Timeout		=>	$timeout,
);
# Confirm this is a Cisco and get ver info
my @verinfo = $session->cmd('show ver | inc Cisco');
my $version = $verinfo[0];
if($version !~ /(^Cisco IOS Software)||(^Cisco Internetwork Operating System Software)/){
	print "$hostname does not appear to be running Cisco IOS!!\n";
	if($outputlog){print $logfh "$hostname does not appear to be running Cisco IOS!!\n";}
	exit 1;
}
# Get enable mode if desired
if($verbose){ print $logbuffer;}
if($outputlog){print $logfh $logbuffer; $logbuffer ='';}

if($opt_e && !$session->is_enabled){
	$session->enable($enablepw);
	if($verbose){ print $logbuffer;}
	if($outputlog){print $logfh $logbuffer; $logbuffer ='';}
}

for(@commands){
	#push(@output, $session->cmd($_));
	$session->cmd(String => $_, Timeout => 20,);
	if($verbose){ print $logbuffer;}
	if($outputlog){print $logfh $logbuffer; $logbuffer ='';}


}

if($logfh){ print $logfh "\n\n## Session to $opt_h ended successfully\n";}
if($logfh){close($logfh);}
close($bufferfh);
################################################

sub print_usage{
	my $missing = shift;
	if($missing eq 'h'){
		print "Required hostname not found!\nSee usage for -h requirement\n\n";
	}
	if($missing eq 'c'){
		print "Required command data not found!\nSee usage for -c or -f requirement\n\n";
	}
    print "Usage: $0 -h hostname \n\n";
	print "NOTE: Either -c or -f arguments are required\n\n";
	print "OPTIONS\n";
	print " -c		Command to run on host, use \; for multiple lines\n";
	print " -e		Set enable mode\n";
	print " -f		Text file containing commands to run\n";
	print " -h		Hostname or IP of device\n";
	print " -n		Enable Mode Password - defaults to our standard\n";#(will prompt if left blank)\n";
	print " -o		Log file to append output information to\n";
	print " -p		Password - defaults to our standard pw\n";#(will prompt if left blank)\n";
	print " -u		Username - defaults to spectrum\n";#(will prompt if left blank)\n";
	print " -v		Verbose mode: display output on screen\n";
	exit 0;

}
