scoredir=$(localstatedir)/games
Gamesdir = $(datadir)/apps/Games

INCLUDES = 			\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir)

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
	-touch $(scoredir)/gnomine.scores
	-chown games.games $(scoredir)/gnomine.scores
	-chmod 664 $(scoredir)/gnomine.scores
	-chgrp games $(bindir)/gnomine && chmod 2111 $(bindir)/gnomine
