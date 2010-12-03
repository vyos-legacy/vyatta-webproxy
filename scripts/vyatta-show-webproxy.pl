#!/usr/bin/perl
#
# Module: vyatta-show-webproxy.pl
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
# Description: webproxy show commands.
# 
# **** End License ****
#

use Getopt::Long;
use POSIX;

use lib "/opt/vyatta/share/perl5";
use Vyatta::Webproxy;

use warnings;
use strict;

sub squid_show_mime {
    my @mime = squid_get_mime();
    exit 0 if scalar(@mime) < 1;
    print join("\n", @mime);
}

sub squidguard_show_blacklists {
    my @lists = squidguard_get_blacklists();

    exit 0 if scalar(@lists) < 1;
    @lists = sort(@lists);
    foreach my $list (@lists) {
	print "$list\n";
    }
}

sub squidguard_show_blacklist_domains_urls {
    my ($type, $category, $searchtext) = @_;

    my $global_data_dir = webproxy_get_global_data_dir();
    my @files = squidguard_get_blacklist_files($type, $category);
    foreach my $file (@files) {
	if (-r $file) {
	    open(my $FILE, "<", $file) or die "Error: read $!";
	    my @lines = <$FILE>;
	    close($FILE);
	    @lines = sort(@lines);
	    if (defined $searchtext) {
		@lines = grep /$searchtext/i, @lines;
		foreach my $line (@lines) {
                    my $db_dir = "$global_data_dir/squidguard/db";
		    $file =~ /^$db_dir\/(.*)$/;
		    print "$1     $line";
		}
	    } else {
		print @lines;
	    }
	}
    }
}

sub squidguard_search_blacklist {
    my $searchtext = shift;

    squidguard_show_blacklist_domains_urls('domains', undef, $searchtext);
    squidguard_show_blacklist_domains_urls('urls',    undef, $searchtext);
}


#
# main
#
my ($action, $category, $searchtext) = undef;

GetOptions("action=s"     => \$action,
	   "category=s"   => \$category,
	   "searchtext=s" => \$searchtext,
);

if (! defined $action) {
    print "Must define action\n";
    exit 1;
}

if ($action eq 'show-blacklists') {
    squidguard_show_blacklists();
    exit 0;
}

if ($action eq 'show-blacklist-domains') {
    squidguard_show_blacklist_domains_urls('domains', $category);
    exit 0;
}

if ($action eq 'show-blacklist-urls') {
    squidguard_show_blacklist_domains_urls('urls', $category);
    exit 0;
}

if ($action eq 'show-mime') {
    squid_show_mime();
    exit 0;
}

if ($action eq 'search-blacklist') {
    squidguard_search_blacklist($searchtext);
    exit 0;
}

print "Unknown action [$action]\n";
exit 1;

# end of file
