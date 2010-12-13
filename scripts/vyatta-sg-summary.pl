#!/usr/bin/perl
#
# Module: vyatta-sg-summary.pl
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
# Description: Script to summarize squidGuard log
# 
# **** End License ****
#

use lib "/opt/vyatta/share/perl5";
use Vyatta::Webproxy qw(squidguard_get_log_files);
use Getopt::Long;

use warnings;
use strict;

#defaults
my $list_requestors = 1;
my $show_top_n      = 10;

#stats
my $total_blocks = 0;
my %categories   = ();
my %users        = ();
my %sites        = ();

my ($http_only, $https_only) = (undef, undef);

GetOptions("http-only!"            => \$http_only,
           "https-only!"           => \$https_only);

my @log_files = squidguard_get_log_files();
if (scalar(@log_files) < 1) {
    print "No webproxy blacklist log\n";
    exit 0;
}

#
# read all logs
#
foreach my $log (@log_files) {
    open(my $fh, '<', $log) || die "Couldn't open $log - $!";    
    while (<$fh>) {
        my ($date, $time, $pid, $category, $url, $requestor, $ident, $method) 
            = split;
        next if !defined($category) or !defined($requestor) or !defined($url);
        if ($category =~ /\/([\w-]+)\//) {
            $category = $1;
        }
        if (!defined $https_only) {
            if ($url =~ /^http:\/\/([^\/]+)\//) {
                $sites{$1}++;
                $total_blocks++;
                $categories{$category}++;
                $users{$requestor}++;
            }
        }
        if (!defined $http_only) {
            if ($url =~ /^(\S+)\:443$/) {
                $sites{$1}++;
                $total_blocks++;
                $categories{$category}++;
                $users{$requestor}++;
            }
        }
    }
    close $fh;
}
exit 0 if $total_blocks < 1;

#
# print summary
#
my $format    = "%-50s  %8s\n";

printf($format, "Blocked category", "Count");
printf($format, "----------------", "-----");
for my $cat (sort {$categories{$b} <=> $categories{$a}} keys %categories) {
    printf($format, $cat, $categories{$cat});
}
printf($format, ' ', "=====");
printf($format, ' ', $total_blocks);
print "\n";

my $num_sites = 0;
printf($format, "Top $show_top_n sites", "Count");
printf($format, "------------", "-----");
for my $site (sort {$sites{$b} <=> $sites{$a}} keys %sites) {
    $num_sites++;
    if ($num_sites <= $show_top_n) {
        printf($format, $site, $sites{$site});
    }
}
print "--\nTotal sites: $num_sites\n\n";

if ($list_requestors) {
    my $num_users = 0;
    printf($format, "Top $show_top_n Requestors", "Blocks");
    printf($format, "-----------------", "------");
    for my $ip (sort {$users{$b} <=> $users{$a}} keys %users) {
        $num_users++;
        if ($num_users <= $show_top_n) {
            printf($format, $ip, $users{$ip});
        }
    }
    print "--\nTotal users: $num_users\n\n";
}

exit 0;

# end of file
