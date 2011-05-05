#!/usr/bin/perl
#
# Module: vyatta-sg-blacklist.pl
# 
# **** License ****
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2008-2009 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: Stig Thormodsrud
# Date: October 2008
# Description: script to download/update free url blacklist.
# 
# **** End License ****
#

use Getopt::Long;
use POSIX;
use IO::Prompt;
use Sys::Syslog qw(:standard :macros);
use File::Copy;
use Fcntl qw(:flock);

use lib "/opt/vyatta/share/perl5";
use Vyatta::Webproxy;
use Vyatta::File;

use warnings;
use strict;

#
# Default blacklist
#
# Below are some free blacklists we've tried:
#
# http://squidguard.mesd.k12.or.us/blacklists.tgz
# http://ftp.teledanmark.no/pub/www/proxy/squidguard/contrib/blacklists.tar.gz
# ftp://ftp.univ-tlse1.fr/pub/reseau/cache/squidguard_contrib/blacklists.tar.gz
#
# Note: the auto install/update assumes that the blacklist url is a tar gz
#       file with the blacklist categorys in a "blacklist" directory.  Some
#       of the commercially available blacklists are a cgi script instead, so
#       those blacklists will need a different install/update script.  Of 
#       course they can be manually installed/updated. 
#
my $blacklist_url = 'ftp://ftp.univ-tlse1.fr/pub/reseau/cache/squidguard_contrib/blacklists.tar.gz';

my $global_data_dir = webproxy_get_global_data_dir();


sub print_err {
    my ($interactive, $msg) = @_;
    if ($interactive) {
	print "$msg\n";
    } else {
	syslog(LOG_ERR, $msg);
    }    
}

sub squidguard_count_blacklist_entries {
    my $db_dir = squidguard_get_blacklist_dir();

    my $total = 0;
    my @categories = squidguard_get_blacklists();
    foreach my $category (@categories) {
	foreach my $type ('domains', 'urls') {
	    my $path = "$category/$type";
	    my $file = "$db_dir/$path";
	    if (-e $file) {
		my $wc = `cat $file| wc -l`; chomp $wc;
		$total += $wc;
	    }
	}
    }
    return $total;
}

sub squidguard_clean_tmpfiles {
    #
    # workaround for squidguard 
    # bug http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=494281
    #
    my @tmpfiles = </var/tmp/*>; 
    foreach my $file (@tmpfiles) {
	my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, 
	    $mtime, $ctime, $blksize, $blocks) = stat($file);
	my $name = (getpwuid($uid))[0] if $uid;
	unlink($file) if $name and $name eq 'proxy';
    }
}

sub squidguard_auto_update {
    my ($interactive, $file) = @_;

    my $rc;
    my $db_dir = squidguard_get_blacklist_dir();
    my $tmp_blacklists = '/tmp/blacklists.gz';

    if (!squidguard_is_blacklist_installed()) {
        my ($disk_free, $disk_required);
        $disk_required = (30 * 1024 * 1024); # 30MB 
        $disk_free = `df $db_dir | grep -v Filesystem | awk '{ print \$4 }'`;
        chomp($disk_free);
        $disk_free *= 1024;
        if ($disk_free < $disk_required) {
            die "Error: not enough disk space $disk_required\/$disk_free";
        }
    }

    if (defined $file) {
      # use existing file
	$rc = copy($file, $tmp_blacklists);
	if (!$rc) {
	    print_err($interactive, "Unable to copy [$file] $!");
	    return 1;
	}
    } else {
      # get from net
	my $opt = '';
	$opt = "-q" if ! $interactive;
	$rc = system("wget -O $tmp_blacklists $opt $blacklist_url");
	if ($rc) {
	    print_err($interactive, "Unable to download [$blacklist_url] $!");
	    return 1;
	}
    }
    
    print "Uncompressing blacklist...\n" if $interactive;
    $rc = system("tar --directory /tmp -zxvf $tmp_blacklists > /dev/null");
    if ($rc) {
	print_err($interactive, "Unable to uncompress [$blacklist_url] $!");
	return 1;
    }
    my $b4_entries = squidguard_count_blacklist_entries();
    my $archive = "$global_data_dir/squidguard/archive";
    mkdir_p($archive) if ! -d $archive;
    system("rm -rf $archive/*");
    system("mv $db_dir/* $archive 2> /dev/null");
    $rc = system("mv /tmp/blacklists/* $db_dir");
    if ($rc) {
	print_err($interactive, "Unable to install [$blacklist_url] $!");
	return 1;
    }
    system("mv $archive/local-* $db_dir 2> /dev/null");
    rm_rf($tmp_blacklists);
    rm_rf("/tmp/blacklists");

    my $after_entries = squidguard_count_blacklist_entries();
    my $mode = "auto-update";
    $mode = "manual" if $interactive;
    syslog(LOG_WARNING, 
	   "blacklist entries updated($mode) ($b4_entries/$after_entries)");
    return 0;
}

sub squidguard_install_blacklist_def {
    squidguard_auto_update(1, undef);
}

sub squidguard_update_blacklist {
    my ($interactive, $update_category) = @_;

    my @blacklists = squidguard_get_blacklists();
    print "Checking permissions...\n" if $interactive;
    my $db_dir = squidguard_get_blacklist_dir();
    system("chown -R proxy.proxy $db_dir > /dev/null 2>&1");
    chmod(2770, $db_dir);

    #
    # generate temporary config for each category & generate DB
    #
    foreach my $category (@blacklists) {
	next if defined $update_category and $update_category ne $category;
	squidguard_generate_db($interactive, $category, 'default');
    }
}


#
# main
#
my ($update_bl, $update_bl_cat, $update_bl_file, $auto_update_bl);

GetOptions("update-blacklist!"           => \$update_bl,
	   "update-blacklist-category=s" => \$update_bl_cat,
	   "update-blacklist-file=s"     => \$update_bl_file,
	   "auto-update-blacklist!"      => \$auto_update_bl,
);

my $sg_updatestatus_file = "$global_data_dir/squidguard/updatestatus";
if (! -e "$global_data_dir/squidguard") {
    system("mkdir -p $global_data_dir/squidguard/db");
    my ($login, $pass, $uid, $gid) = getpwnam('proxy')
        or die "proxy not in passwd file";
    chown $uid, $gid, "$global_data_dir/squidguard/db";
}
touch($sg_updatestatus_file);
system("echo update failed at `date` > $sg_updatestatus_file");
system("sudo rm -f /var/lib/sitefilter/updatestatus");

my $lock_file = '/tmp/vyatta_bl_lock';
open(my $lck, ">", $lock_file) || die "Lock failed\n";
flock($lck, LOCK_EX);

if (defined $update_bl_cat) {
    squidguard_update_blacklist(1, $update_bl_cat);
    if (squidguard_is_configured()) {
	print "\nThe webproxy daemon must be restarted\n";
	if ((defined($ENV{VYATTA_PROCESS_CLIENT}) && $ENV{VYATTA_PROCESS_CLIENT} eq 'gui2_rest') || 
	    prompt("Would you like to restart it now? [confirm]",-y1d=>"y")) {
	    squid_restart(1);
	}
    }
    squidguard_clean_tmpfiles();
}

if (defined $update_bl) {
    my $updated = 0;
    if (!squidguard_is_blacklist_installed()) {
	print "Warning: No url-filtering blacklist installed\n";
	if ((defined($ENV{VYATTA_PROCESS_CLIENT}) && $ENV{VYATTA_PROCESS_CLIENT} eq 'gui2_rest') || 
	    prompt("Would you like to download a default blacklist? [confirm]", 
		   -y1d=>"y")) {
	    exit 1 if squidguard_install_blacklist_def();
	    $updated = 1;
	} else {
	    exit 1;
	}
    } else {
	if ((defined($ENV{VYATTA_PROCESS_CLIENT}) && $ENV{VYATTA_PROCESS_CLIENT} eq 'gui2_rest') || 
	    prompt("Would you like to re-download the blacklist? [confirm]", 
		   -y1d=>"y")) {
	    my $rc = squidguard_auto_update(1, undef);
	    $updated = 1 if ! $rc;
	}
    }
    if (! $updated) {
	print "No blacklist updated\n";
	if ((defined($ENV{VYATTA_PROCESS_CLIENT}) && $ENV{VYATTA_PROCESS_CLIENT} eq 'gui2_rest') || 
	    !prompt("Do you still want to generate binary DB? [confirm]", 
		   -y1d=>"y")) {
	    exit 1;
	}
    }
    # if there was an update we need to re-gen the binary DBs 
    # and restart the daemon
    squidguard_update_blacklist(1);
    if (squidguard_is_configured()) {
	print "\nThe webproxy daemon must be restarted\n";
	if ((defined($ENV{VYATTA_PROCESS_CLIENT}) && $ENV{VYATTA_PROCESS_CLIENT} eq 'gui2_rest') || 
	    prompt("Would you like to restart it now? [confirm]",-y1d=>"y")) {
	    squid_restart(1);
	}
    }
    squidguard_clean_tmpfiles();
}

if (defined $update_bl_file) {
    if (! -e $update_bl_file) {
 	die "Error: file [$update_bl_file] doesn't exist";
    }
    my $rc = squidguard_auto_update(0, $update_bl_file);
    exit 1 if $rc;
    squidguard_update_blacklist(1);
    squidguard_clean_tmpfiles();
}

if (defined $auto_update_bl) {
    my $rc = squidguard_auto_update(0);
    exit 1 if $rc;
    squidguard_update_blacklist(0);
    if (squidguard_is_configured()) {
	squid_restart(0);
    }
    squidguard_clean_tmpfiles();
}

system("echo update succeeded at `date` > $sg_updatestatus_file");
close($lck);
exit 0;

#end of file
