cfgdir		  = $(datadir)/vyatta-cfg/templates
opdir		  = $(datadir)/vyatta-op/templates
share_perl5dir	  = $(datarootdir)/perl5
bin_sudo_usersdir = $(bindir)/sudo-users
cgidir            = /usr/lib/cgi-bin
wwwdir            = /var/www/images

sbin_SCRIPTS  = scripts/vyatta-update-webproxy.pl
sbin_SCRIPTS += scripts/install-blacklist

bin_sudo_users_SCRIPTS = scripts/vyatta-show-webproxy.pl

share_perl5_DATA  = scripts/VyattaWebproxy.pm

cgi_SCRIPTS = cgi/squidGuard-simple.cgi

www_DATA = www/blocked.gif

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
  cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates-cfg; $(cpiop) $(DESTDIR)$(cfgdir)
	mkdir -p $(DESTDIR)$(opdir)
	cd templates-op; $(cpiop) $(DESTDIR)$(opdir)
