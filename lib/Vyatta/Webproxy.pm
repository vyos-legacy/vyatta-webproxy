#
# Module: VyattaWebproxy.pm
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
# Date: September 2008
# Description: Common webproxy definitions/funcitions
# 
# **** End License ****
#
package Vyatta::Webproxy;
use strict;
use warnings;

our @EXPORT = qw(
	squidguard_build_dest
	squidguard_generate_db
	squidguard_get_blacklist_dir
	squidguard_get_blacklist_domains_urls_exps
	squidguard_get_blacklist_files
	squidguard_get_blacklist_log
	squidguard_get_blacklists
	squidguard_get_log_files
	squidguard_is_blacklist_installed
	squidguard_is_configured
	squid_restart
	squid_stop
        squid_get_mime
	webproxy_write_file
);
use base qw(Exporter);
use File::Basename;
use Vyatta::Config;

#squid globals
my $squid_init      = '/etc/init.d/squid3';
my $squid_mime_type = '/usr/share/squid3/mime.conf';

#squidGuard globals
my $squidguard_blacklist_db  = '/var/lib/squidguard/db';
my $squidguard_log_dir       = '/var/log/squid';
my $squidguard_blacklist_log = "$squidguard_log_dir/blacklist.log";


sub squid_restart {
    my $interactive = shift;

    my $opt = '';
    $opt = "> /dev/null 2>&1" if ! $interactive;
    system("$squid_init restart $opt");
}

sub squid_stop {
    system("$squid_init stop");
}

sub squid_get_mime {
    my @mime_types = ();
    open(my $FILE, "<", $squid_mime_type) or die "Error: read $!";
    my @lines = <$FILE>;
    close($FILE);
    foreach my $line (@lines) {
	next if $line =~ /^#/;         # skip comments
	if ($line =~ /^([\S]+)[\s]+([\S]+)[\s]+([\S]+)[\s]+([\S]+).*$/) {
	    my $type = $2;
	    push @mime_types, $type if $type =~ /\//;
	}
    }
    return @mime_types;
}

sub squidguard_is_configured {
    my $config = new Vyatta::Config;
    my $path = "service webproxy url-filtering squidguard";

    $config->setLevel("service webproxy url-filtering");
    # This checks the running config, so it is assumed 
    # to be called from op mode.
    return 1 if $config->existsOrig("squidguard");
    return 0;
}

sub squidguard_get_blacklist_dir {
    return $squidguard_blacklist_db;
}

sub squidguard_get_blacklist_log {
    return $squidguard_blacklist_log;
}

sub squidguard_get_blacklists {
    my $dir = $squidguard_blacklist_db;

    my @blacklists = ();
    opendir(DIR, $dir) || die "can't opendir $dir: $!";
    my @dirs = readdir(DIR);
    closedir DIR;

    foreach my $file (@dirs) {
	next if $file eq '.';
	next if $file eq '..';
	if (-d "$dir/$file") {
	    push @blacklists, $file;
	}
    }
    return sort(@blacklists);
}

sub squidguard_generate_db {
    my ($interactive, $category) = @_;

    my $db_dir   = squidguard_get_blacklist_dir();
    my $tmp_conf = "/tmp/sg.conf.$$";
    my $output   = "dbhome $db_dir\n";
    $output     .= squidguard_build_dest($category, 0);
    $output     .= "\nacl {\n";
    $output     .= "\tdefault {\n";
    $output     .= "\t\tpass all\n";
    $output     .= "\t}\n}\n\n";
    webproxy_write_file($tmp_conf, $output);

    my $dir = "$db_dir/$category";
    if ( -l $dir) {
	print "Skip link for   [$category] -> [", readlink($dir), "]\n" 
	    if $interactive;
	return;
    }
    foreach my $type ('domains', 'urls', 'expressions') {
	my $path = "$category/$type";
	my $file = "$db_dir/$path";
	if (-e $file and -s _) {  # check exists and non-zero
	    my $file_db = "$file.db";
	    if (! -e $file_db) {
		#
		# it appears that there is a bug in squidGuard that if
		# the db file doesn't exist then running with -C leaves
		# huge tmp files in /var/tmp.
		#
		system("touch $file.db");
		system("chown -R proxy.proxy $file.db > /dev/null 2>&1");
	    }
	    my $wc = `cat $file| wc -l`; chomp $wc;
	    print "Building DB for [$path] - $wc entries\n" if $interactive;
	    my $cmd = "\"squidGuard -d -c $tmp_conf -C $path\"";
	    system("su - proxy -c $cmd > /dev/null 2>&1");
	}
    }
    system("rm $tmp_conf");
}

sub squidguard_is_blacklist_installed {
    my @blacklists = squidguard_get_blacklists();
    foreach my $category (@blacklists) {
	next if $category eq 'local-ok';
	next if $category eq 'local-block';
	return 1;
    }
    return 0;
}

sub squidguard_get_blacklist_domains_urls_exps {
    my ($list) = shift;

    my $dir = $squidguard_blacklist_db;

    my ($domains, $urls, $exps) = undef;
    $domains = "$list/domains"     if -f "$dir/$list/domains" && -s _;
    $urls    = "$list/urls"        if -f "$dir/$list/urls" && -s _;
    $exps    = "$list/expressions" if -f "$dir/$list/expressions" && -s _;
    return ($domains, $urls, $exps);
}

sub squidguard_get_blacklist_files {
    my ($type, $category) = @_;

    my @lists = squidguard_get_blacklists();
    
    my @files = ();
    foreach my $list (@lists) {
	my ($domain, $url, $exp) = squidguard_get_blacklist_domains_urls_exps(
	    $list);
	if ($type eq 'domains') {
	    next if !defined $domain;
	    if (defined $category) {
		next if $domain ne "$category/domains";
	    }
	    $domain = "$squidguard_blacklist_db/$domain";
	    push @files, $domain;
	}
	if ($type eq 'urls') {
	    next if !defined $url;
	    if (defined $category) {
		next if $url ne "$category/urls";
	    }
	    $url = "$squidguard_blacklist_db/$url";
	    push @files, $url;
	}
	if ($type eq 'expressions') {
	    next if !defined $exp;
	    if (defined $category) {
		next if $url ne "$category/expressions";
	    }
	    $exp = "$squidguard_blacklist_db/$exp";
	    push @files, $exp;
	}

    }
    @files = sort(@files);
    return @files;
}

sub squidguard_get_log_files {
    open(my $LS, "ls $squidguard_log_dir/bl*.log* 2> /dev/null | sort -nr |");
    my @log_files = <$LS>;
    close $LS;
    chomp @log_files;
    return @log_files;
}

sub squidguard_build_dest {
    my ($category, $logging) = @_;

    my $output = "";
    my ($domains, $urls, $exps) =
	squidguard_get_blacklist_domains_urls_exps($category);
    if (!defined $domains and !defined $urls and !defined $exps) {
	return "";
    }
    $output  = "dest $category {\n";
    $output .= "\tdomainlist     $domains\n" if defined $domains;
    $output .= "\turllist        $urls\n"    if defined $urls;
    $output .= "\texpressionlist $exps\n"    if defined $exps;
    if ($logging) {
	my $log = basename($squidguard_blacklist_log);
	$output .= "\tlog            $log\n";
    }
    $output .= "}\n\n";
    return $output;
}

sub webproxy_write_file {
    my ($file, $config) = @_;

    open(my $fh, '>', $file) || die "Couldn't open $file - $!";
    print $fh $config;
    close $fh;
}

1;
