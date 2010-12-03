cfgdir		  = $(datadir)/vyatta-cfg/templates
opdir		  = $(datadir)/vyatta-op/templates
share_perl5dir	  = $(datarootdir)/perl5/Vyatta
bin_sudo_usersdir = $(bindir)/sudo-users
cgidir            = /usr/lib/cgi-bin
wwwdir            = /var/www/images
curverdir         = $(sysconfdir)/config-migrate/current

curver_DATA = cfg-version/webproxy@1

sbin_SCRIPTS  = scripts/vyatta-update-webproxy.pl
sbin_SCRIPTS += scripts/test_uf

bin_sudo_users_SCRIPTS  = scripts/vyatta-show-webproxy.pl
bin_sudo_users_SCRIPTS += scripts/vyatta-sg-summary.pl
bin_sudo_users_SCRIPTS += scripts/vyatta-sg-blacklist.pl
bin_sudo_users_SCRIPTS += scripts/vyatta-restart-squid

share_perl5_DATA  = lib/Vyatta/Webproxy.pm

cgi_SCRIPTS = cgi/squidGuard-simple.cgi

www_DATA = www/blocked.gif

sysconf_DATA  = sysconf/safesearch_rewrites


cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
  cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates-cfg; $(cpiop) $(DESTDIR)$(cfgdir)
	mkdir -p $(DESTDIR)$(opdir)
	cd templates-op; $(cpiop) $(DESTDIR)$(opdir)
