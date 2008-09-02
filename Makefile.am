cfgdir		 = $(datadir)/vyatta-cfg/templates
opdir		 = $(datadir)/vyatta-op/templates
share_perl5dir	 = $(datarootdir)/perl5
#cron_hourlydir = /etc/cron.hourly

sbin_SCRIPTS  = scripts/vyatta-update-webproxy.pl
sbin_SCRIPTS += scripts/install-blacklist


#cron_hourly_SCRIPTS = scripts/vyatta-webproxy-update

#share_perl5_DATA  = scripts/VyattaWebproxyConfig.pm

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
  cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates-cfg; $(cpiop) $(DESTDIR)$(cfgdir)
	mkdir -p $(DESTDIR)$(opdir)
	cd templates-op; $(cpiop) $(DESTDIR)$(opdir)

