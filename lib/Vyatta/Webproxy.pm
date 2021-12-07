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
# Portions created by Vyatta are Copyright (C) 2008-2010 Vyatta, Inc.
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
        squidguard_is_category_local
	squid_restart
	squid_stop
        squid_get_mime
	webproxy_write_file
	webproxy_append_file
        webproxy_delete_local_entry
        webproxy_delete_all_local
        webproxy_get_global_data_dir
        squidguard_use_ec
        squidguard_ec_name2cat
        squidguard_get_safesearch_rewrites
);
use base qw(Exporter);
use File::Basename;
use File::Compare;
use Vyatta::Config;

#squid globals
my $squid_mime_type = '/usr/share/squid/mime.conf';

#squidGuard globals
my $urlfilter_data_dir            = '/opt/vyatta/etc/config/url-filtering';
my $squidguard_blacklist_db  = "$urlfilter_data_dir/squidguard/db";
my $squidguard_log_dir       = '/var/log/squid';
my $squidguard_blacklist_log = "$squidguard_log_dir/blacklist.log";
my $squidguard_safesearch    = "/opt/vyatta/etc/safesearch_rewrites";

#vyattaguard globals
my $vyattaguard = '/opt/vyatta/sbin/vg';

sub webproxy_get_global_data_dir {
    return $urlfilter_data_dir;
}

sub squid_restart {
    my $interactive = shift;

    my $opt = '';
    $opt = "> /dev/null 2>&1" if ! $interactive;
    system("systemctl restart squid.service $opt");
}

sub squid_stop {
    system("systemctl stop squid.service");
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
    $config->setLevel('service webproxy url-filtering');
    # This checks the running config, so it is assumed 
    # to be called from op mode.
    return 1 if $config->existsOrig('squidguard');
    return 0;
}

sub squidguard_get_blacklist_dir {
    return $squidguard_blacklist_db;
}

sub squidguard_get_blacklist_log {
    return $squidguard_blacklist_log;
}

sub squidguard_get_safesearch_rewrites {
    my @rewrites = ();
    open(my $FILE, "<", $squidguard_safesearch) or die "Error: read $!";
    my @lines = <$FILE>;
    close($FILE);
    chomp @lines;
    foreach my $line (@lines) {
	next if $line =~ /^#/;         # skip comments
        if ($line =~ /^s\@/) {
            push @rewrites, $line;
        }
    }
    return @rewrites;
}

sub squidguard_ec_get_categorys {
    my %cat_hash;

    die "Must enable vyattaguard" if ! squidguard_use_ec();
    die "Missing vyattaguard package\n" if ! -e $vyattaguard;
    exit 1 if ! -e "$urlfilter_data_dir/sitefilter/categories.txt";

    my @lines = `$vyattaguard list`;
    foreach my $line (@lines) {
        my ($id, $category) = split ':', $line;
        next if ! defined $category;
        chomp $category;
        $category =~ s/\s/\_/g;
        $category =~ s/\&/\_and\_/g;
        $cat_hash{$id} = $category;
    }
    return %cat_hash;
}

sub squidguard_ec_cat2name {
    my ($cat) = @_;

    my %cat_hash = squidguard_ec_get_categorys();
    return $cat_hash{$cat} if defined $cat_hash{$cat};
    return;
}

sub squidguard_ec_name2cat {
    my ($name) = @_;

    my %cat_hash = squidguard_ec_get_categorys();
    foreach my $key (keys (%cat_hash)) {
        if ($cat_hash{$key} eq $name) {
            return $key;
        }
    }
    return;
}

sub squidguard_use_ec {
    my $rc = system("cli-shell-api inSession");
    my ($exist_func, $value_func);
    if ($rc == 0) {
        $exist_func = 'exists';
        $value_func = 'returnValue';
    } else {
        $exist_func = 'existsOrig';
        $value_func = 'returnOrigValue';
    }
    my $config = new Vyatta::Config;
    $config->setLevel('service webproxy url-filtering squidguard');
    if ($config->$exist_func('vyattaguard')) {
        return if ! -e $vyattaguard;
        my $mode = $config->$value_func('vyattaguard mode');
        return $mode;
    }
    return;
}

sub squidguard_get_blacklists {

    my @blacklists = ();
    if (squidguard_use_ec()) {
        die "Missing vyattaguard package\n" if ! -e $vyattaguard;
        my %cat_hash = squidguard_ec_get_categorys();
        foreach my $key (keys (%cat_hash)) {
            next if ! defined $cat_hash{$key};
            push @blacklists, $cat_hash{$key};
        }
    } else {
        my $dir = $squidguard_blacklist_db;
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
    }
    @blacklists = sort(@blacklists);
    return @blacklists;
}

sub squidguard_generate_db {
    my ($interactive, $category, $group) = @_;

    my $db_dir   = squidguard_get_blacklist_dir();
    my $tmp_conf = "/tmp/sg.conf.$$";
    my $output   = "dbhome $db_dir\n";
    $output     .= squidguard_build_dest($category, 0, $group);
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

sub squidguard_is_category_local {
    my ($category) = @_;

    my $db_dir = squidguard_get_blacklist_dir();
    my $local_file = "$db_dir/$category/local";
    return 1 if -e $local_file;
    return 0;
}

sub squidguard_is_blacklist_installed {
    if (squidguard_use_ec()) {
        if (-e "$urlfilter_data_dir/sitefilter/urldb") {
            return 1;
        }
    } else {
        my @blacklists = squidguard_get_blacklists();
        foreach my $category (@blacklists) {
            next if squidguard_is_category_local($category);
            return 1;
        }
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
    open(my $LS, "-|", "ls $squidguard_log_dir/bl*.log* 2> /dev/null | sort -nr ");
    my @log_files = <$LS>;
    close $LS;
    chomp @log_files;
    return @log_files;
}

sub squidguard_build_dest {
    my ($category, $logging, $group, $ec) = @_;

    my $output = '';
    my ($domains, $urls, $exps);
    if (squidguard_is_category_local("$category-$group")) {
	($domains, $urls, $exps) = squidguard_get_blacklist_domains_urls_exps(
	    "$category-$group");
    } else {
	($domains, $urls, $exps) = squidguard_get_blacklist_domains_urls_exps(
	    $category);
    }

    my $ec_cat = undef;
    if  (defined $ec) {
        $ec_cat = squidguard_ec_name2cat($category);
    }

    $output  = "dest $category-$group {\n";
    $output .= "\tdomainlist     $domains\n" if defined $domains;
    $output .= "\turllist        $urls\n"    if defined $urls;
    $output .= "\texpressionlist $exps\n"    if defined $exps;
    $output .= "\teccategory     $ec_cat\n"  if defined $ec_cat;
    if ($logging) {
	my $log = basename($squidguard_blacklist_log);
	$output .= "\tlog            $log\n";
    }
    $output .= "}\n\n";
    return $output;
}

sub webproxy_read_file {
    my ($file) = @_;
    my @lines;
    if ( -e $file) {
	open(my $FILE, '<', $file) or die "Error: read $!";
	@lines = <$FILE>;
	close($FILE);
	chomp @lines;
    }
    return @lines;
}

sub is_same_as_file {
    my ($file, $value) = @_;

    return if ! -e $file;

    my $mem_file = '';
    open my $MF, '+<', \$mem_file or die "couldn't open memfile $!\n";
    print $MF $value;
    seek($MF, 0, 0);
    
    my $rc = compare($file, $MF);
    return 1 if $rc == 0;
    return;
}

sub webproxy_write_file {
    my ($file, $config) = @_;

    # Avoid unnecessary writes.  At boot the file will be the
    # regenerated with the same content.
    return if is_same_as_file($file, $config);

    open(my $fh, '>', $file) || die "Couldn't open $file - $!";
    print $fh $config;
    close $fh;
    return 1;
}

sub webproxy_append_file {
    my ($dst, $src) = @_;

    open(my $ih, '<', $src) || die "Couldn't open $src - $!";
    open(my $oh, '>>', $dst) || die "Couldn't open $dst - $!";
    for (<$ih>) {
        print $oh $_;
    }
    close($oh);
    close($ih);
    return 1;
}

sub webproxy_delete_local_entry {
    my ($file, $value) = @_;

    my $db_dir = squidguard_get_blacklist_dir();
    $file = "$db_dir/$file";
    my @lines = webproxy_read_file($file);
    my $config = '';
    foreach my $line (@lines) {
	$config .= "$line\n" if $line ne $value;
    }
    if ($config eq '') {
	unlink($file);
    } else {
	webproxy_write_file($file, $config);
    }
    return;
}

sub webproxy_delete_all_local {
    my $db_dir = squidguard_get_blacklist_dir();
    my @categorys = squidguard_get_blacklists();
    foreach my $category (@categorys) {
	if (squidguard_is_category_local($category)) {
	    system("rm -rf $db_dir/$category");
	}
    }
    return;
}

1;
