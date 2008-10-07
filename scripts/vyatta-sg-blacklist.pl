#!/usr/bin/perl
#
# Module: 
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
# Portions created by Vyatta are Copyright (C) 2008 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: Stig Thormodsrud
# Date: October 2008
# Description: 
# 
# **** End License ****
#

use Getopt::Long;
use POSIX;
use IO::Prompt;
use Sys::Syslog qw(:standard :macros);

use lib "/opt/vyatta/share/perl5/";
use VyattaWebproxy;

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
my $blacklist_url = 'http://squidguard.mesd.k12.or.us/blacklists.tgz';

sub print_err {
    my ($interactive, $msg) = @_;
    if ($interactive) {
	print "$msg\n";
    } else {
	syslog("error", $msg);
    }    
}

sub squidguard_count_blacklist_entries {
    my $db_dir = VyattaWebproxy::squidguard_get_blacklist_dir();

    my $total = 0;
    my @categories = VyattaWebproxy::squidguard_get_blacklists();
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

sub squidguard_auto_update {
    my $interactive = shift;

    my $db_dir = VyattaWebproxy::squidguard_get_blacklist_dir();
    my $tmp_blacklists = '/tmp/blacklists.gz';
    my $opt = '';
    $opt = "-q" if ! $interactive;
    my $rc = system("wget -O $tmp_blacklists $opt $blacklist_url");
    if ($rc) {
	print_err($interactive, "Unable to download [$blacklist_url] $!");
	return 1;
    }
    
    print "Uncompressing blacklist...\n" if $interactive;
    $rc = system("tar --directory /tmp -zxvf $tmp_blacklists > /dev/null");
    if ($rc) {
	print_err($interactive, "Unable to uncompress [$blacklist_url] $!");
	return 1;
    }
    my $b4_entries = squidguard_count_blacklist_entries();
    my $archive = '/var/lib/squidguard/archive';
    system("mkdir -p $archive") if ! -d $archive;
    system("rm -rf $archive/*");
    system("mv $db_dir/* $archive 2> /dev/null");
    $rc = system("mv /tmp/blacklists/* $db_dir");
    if ($rc) {
	print_err($interactive, "Unable to install [$blacklist_url] $!");
	return 1;
    }
    system("mv $archive/local-* $db_dir 2> /dev/null");
    system("rm -fr $tmp_blacklists /tmp/blacklists");

    my $after_entries = squidguard_count_blacklist_entries();
    syslog("warning", "blacklist entries updated ($b4_entries/$after_entries)");
    return 0;
}

sub squidguard_install_blacklist_def {
    squidguard_auto_update(1);
}

sub squidguard_update_blacklist {
    my $interactive = shift;

    if (!VyattaWebproxy::squidguard_is_blacklist_installed()) {
	print_err($interactive, "No url-filtering blacklist installed");
	exit 1 if ! $interactive;
	if (prompt("Would you like to download a blacklist? [confirm]", 
		   -y1d=>"y")) {
	    exit 1 if squidguard_install_blacklist_def();
	} else {
	    exit 1;
	}
    }

    my @blacklists = VyattaWebproxy::squidguard_get_blacklists();
    print "Checking permissions...\n" if $interactive;
    my $db_dir = VyattaWebproxy::squidguard_get_blacklist_dir();
    system("chown -R proxy.proxy $db_dir > /dev/null 2>&1");
    system("chmod 2770 $db_dir >/dev/null 2>&1");

    #
    # generate temporary config for each category & generate DB
    #
    foreach my $category (@blacklists) {
	VyattaWebproxy::squidguard_generate_db($interactive, $category);
    }
}


#
# main
#
my $update_blacklist;
my $auto_update;

GetOptions("update-blacklist!" => \$update_blacklist,
	   "auto-update!"      => \$auto_update,
);

if (defined $update_blacklist) {
    squidguard_update_blacklist(1);
    VyattaWebproxy::squid_restart(1);
    exit 0;
}

if (defined $auto_update) {
    squidguard_auto_update(0);
    squidguard_update_blacklist(0);
    VyattaWebproxy::squid_restart(0);
    exit 0;
}

exit 1;
