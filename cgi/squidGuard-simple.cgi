#! /usr/bin/perl
#
# Sample CGI to explain to the user that the URL is blocked 
# and by which rule set
#
# By Pål Baltzersen 1998
#

use strict;
use warnings;

#
# Uncomment and provide a real email address if you want it included in the 
# redirect page.
#
#$admin = 'admin@foobar.com';
#
my $admin = undef;

my $QUERY_STRING  = $ENV{'QUERY_STRING'};
my $DOCUMENT_ROOT = $ENV{'DOCUMENT_ROOT'};

my $clientaddr  = "";
my $clientname  = "";
my $clientident = "";
my $srcclass    = "";
my $targetclass = "";
my $url         = "";

my $time = time;
my @day  = ("Sunday", "Monday", "Tuesday", "Wednesday",
	 "Thursday","Friday","Saturday");
my @month = ("Jan","Feb","Mar","Apr","May","Jun",
	  "Jul","Aug","Sep","Oct","Nov","Dec");

my $params = 'clientaddr|clientname|clientident|srcclass|targetclass|url';
while ($QUERY_STRING =~ /^\&?([^&=]+)=([^&=]*)(.*)/) {
    my $key = $1;
    my $value = $2;
    $QUERY_STRING = $3;
    if ($key =~ /^($params)$/) {
	eval "\$$key = \$value";
    }
    if ($QUERY_STRING =~ /^url=(.*)/) {
	$url = $1;
	$QUERY_STRING = "";
    }
}

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);
my $expire_time = sprintf("Expires: %s, %02d-%s-%02d %02d:%02d:%02d GMT\n\n", 
		      $day[$wday], $mday, $month[$mon], 
		      $year, $hour, $min, $sec);

if ($url =~ /\.(gif|jpg|jpeg|mpg|mpeg|avi|mov)$/i) {
    print "Content-Type: image/gif\n";
    print "$expire_time";
    open(GIF, "$DOCUMENT_ROOT/images/blocked.gif");
    while (<GIF>) {
	print;
    }
    close(GIF)
} else {
    print "Content-type: text/html\n";
    print "$expire_time";
    print "<HTML>\n\n <HEAD>\n <TITLE>302 Access denied</TITLE>\n </HEAD>\n\n";
    print "<BODY BGCOLOR=\"#FFFFFF\">\n";
    if ($srcclass eq "unknown") {
	print "<H1 ALIGN=CENTER>Access denied because<BR>";
	print "this client is not<BR>defined on the proxy</H1>\n\n";
	print "<TABLE BORDER=0 ALIGN=CENTER>\n";
	print "<TR><TH ALIGN=RIGHT>Supplementary info";
	print "<TH ALIGN=CENTER>:<TH ALIGN=LEFT>\n";
	if ($clientaddr ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client address";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientaddr\n";
	}
	if ($clientname ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client name";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientname\n";
	}
	if ($clientident ne "") {
	    print "<TR><TH ALIGN=RIGHT>User ident";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientident\n";
	}
	if ($srcclass ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client group";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$srcclass\n";
	}
	print "</TABLE>\n\n";
	print "<P ALIGN=CENTER>If this is wrong, contact<BR>\n";
	if (defined $admin) {
	    print "<A HREF=mailto:$admin>$admin</A>\n";
	} else {
	    print "<A ALIGN=CENTER>your network administrator.<BR>\n";
	}
	print "</P>\n\n";
    } elsif ($targetclass eq "in-addr") {
	print "<H1 ALIGN=CENTER>IP address URLs<BR>are not allowed<BR>";
	print "from this client</H1>\n\n";
	print "<TABLE BORDER=0 ALIGN=CENTER>\n";
	print "<TR><TH ALIGN=RIGHT>Supplementary info";
	print "<TH ALIGN=CENTER>:<TH ALIGN=LEFT>\n";
	if ($clientaddr ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client address";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientaddr\n"
	}
	if ($clientname ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client name";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientname\n";
	}
	if ($clientident ne "") {
	    print "<TR><TH ALIGN=RIGHT>User ident";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientident\n";
	}
	if ($srcclass ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client group";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$srcclass\n";
	}
	print "<TR><TH ALIGN=RIGHT>URL<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$url\n";
	print "<TR><TH ALIGN=RIGHT>Target class";
	print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$targetclass\n";
	print "</TABLE>\n\n";
	print "<P ALIGN=CENTER>Contact the <B>webmaster</B> of ";
	print "<B>$url</B><BR>\n";
	print "and ask him to give the webserver a proper <U>domain name</U>\n";
	print "</P>\n\n";
    } else {
	print "<H1 ALIGN=CENTER>Access denied</H1>\n\n";
	print "<TABLE BORDER=0 ALIGN=CENTER>\n";

	print "<TR><TH ALIGN=RIGHT>Supplementary info";
	print "<TH ALIGN=CENTER>:<TH ALIGN=LEFT>\n";
	if ($clientaddr ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client address";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientaddr\n";
	}
	if ($clientname ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client name";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientname\n";
	}
	if ($clientident ne "") {
	    print "<TR><TH ALIGN=RIGHT>User ident";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$clientident\n";
	}
	if ($srcclass ne "") {
	    print "<TR><TH ALIGN=RIGHT>Client group";
	    print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$srcclass\n";
	}
	print "<TR><TH ALIGN=RIGHT>URL<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$url\n";
	print "<TR><TH ALIGN=RIGHT>Target class";
	print "<TH ALIGN=CENTER>=<TH ALIGN=LEFT>$targetclass\n";
	print "</TABLE>\n\n";
	print "<P ALIGN=CENTER>If this is wrong, contact<BR>\n";
	if (defined $admin) {
	    print "<A HREF=mailto:$admin>$admin</A>\n";
	} else {
	    print "<A ALIGN=CENTER>your network administrator.<BR>\n";
	}
	print "</P>\n\n";
    }
    print "</BODY>\n\n</HTML>\n";
}
exit 0;
