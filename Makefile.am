scoredir=$(localstatedir)/games
Gamesdir = $(datadir)/gnome/apps/Games

SUBDIRS = help

INCLUDES = 			\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir)				 \
	$(GNOME_INCLUDEDIR)

bin_PROGRAMS = gnomine

gnomine_SOURCES =	\
	gnomine.c	\
	minefield.h	\
	minefield.c

gnomine_LDADD = \
	$(GNOME_LIBDIR) \
	$(GNOMEUI_LIBS)	\
	$(INTLLIBS)

EXTRA_DIST = flag.xpm mine.xpm face-cool.xpm face-sad.xpm \
	face-smile.xpm face-win.xpm face-worried.xpm \
	gnomine.desktop README AUTHORS

Games_DATA = gnomine.desktop

install-data-local:
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-touch $(DESTDIR)$(scoredir)/gnomine.Tiny.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnomine.Tiny.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnomine.Tiny.scores	
	-touch $(DESTDIR)$(scoredir)/gnomine.Medium.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnomine.Medium.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnomine.Medium.scores	
	-touch $(DESTDIR)$(scoredir)/gnomine.Biiiig.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnomine.Biiiig.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnomine.Biiiig.scores	
	-touch $(DESTDIR)$(scoredir)/gnomine.Custom.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnomine.Custom.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnomine.Custom.scores	
	-chgrp games $(DESTDIR)$(bindir)/gnomine && chmod 2111 $(DESTDIR)$(bindir)/gnomine
