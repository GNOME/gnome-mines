scoredir=$(localstatedir)/games
Gamesdir = $(datadir)/gnome/apps/Games

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
	-$(mkinstalldirs) $(scoredir)
	-touch $(scoredir)/gnomine.Tiny.scores
	-chown games.games $(scoredir)/gnomine.Tiny.scores
	-chmod 664 $(scoredir)/gnomine.Tiny.scores	
	-touch $(scoredir)/gnomine.Medium.scores
	-chown games.games $(scoredir)/gnomine.Medium.scores
	-chmod 664 $(scoredir)/gnomine.Medium.scores	
	-touch $(scoredir)/gnomine.Biiiig.scores
	-chown games.games $(scoredir)/gnomine.Biiiig.scores
	-chmod 664 $(scoredir)/gnomine.Biiiig.scores	
	-touch $(scoredir)/gnomine.Custom.scores
	-chown games.games $(scoredir)/gnomine.Custom.scores
	-chmod 664 $(scoredir)/gnomine.Custom.scores	
	-chgrp games $(bindir)/gnomine && chmod 2111 $(bindir)/gnomine
