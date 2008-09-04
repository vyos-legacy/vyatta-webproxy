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
package VyattaWebproxy;

my $squidguard_blacklist_db  = '/var/lib/squidguard/db';

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
    return @blacklists;
}

sub squidguard_get_blacklist_domains_urls_exps {
    my ($list) = shift;

    my $dir = $squidguard_blacklist_db;

    my ($domains, $urls, $exps) = undef;
    $domains = "$list/domains"     if -f "$dir/$list/domains";
    $urls    = "$list/urls"        if -f "$dir/$list/urls";
    $exps    = "$list/expressions" if -f "$dir/$list/expressions";
    return ($domains, $urls, $exps);
}

1;
