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

use lib "/opt/vyatta/share/perl5/";
use VyattaWebproxy;

use warnings;
use strict;


sub squidguard_show_blacklists {
    my @lists = VyattaWebproxy::squidguard_get_blacklists();

    if (scalar(@lists) < 1) {
	exit 0;
    }

    @lists = sort(@lists);
    foreach my $list (@lists) {
	print "$list\n";
    }
    exit 0;
}


#
# main
#
my $action;

GetOptions("action=s" => \$action,
);

if (! defined $action) {
    print "Must define action\n";
    exit 1;
}

if ($action eq "show-blacklists") {
    squidguard_show_blacklists();
}

# end of file
