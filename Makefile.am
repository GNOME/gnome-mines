scoredir=$(localstatedir)/games
Gamesdir = $(datadir)/apps/Games

INCLUDES = 			\
	-I../.. 		\
	-I$(srcdir)/../.. 	\
	-I$(includedir)		\
	$(X_CFLAGS)

bin_PROGRAMS = gnomine

gnomine_SOURCES =	\
	gnomine.c	\
	minefield.h	\
	minefield.c

gnomine_LDADD = \
	$(top_builddir)/libgnomeui/libgnomeui.la 	\
	$(top_builddir)/libgnome/libgnome.la		\
	$(GTK_LIBS)					\
        $(X_LIBS) $(x_libs) $(INTLLIBS) $(DL_LIB)

EXTRA_DIST = flag.xpm mine.xpm face-cool.xpm face-sad.xpm face-smile.xpm face-win.xpm face-worried.xpm \
	     gnomine.desktop README AUTHORS

install-data-local:
	$(mkinstalldirs) $(Gamesdir)
	$(INSTALL_DATA) $(srcdir)/gnomine.desktop $(datadir)/apps/Games/"Gnome Mines.desktop"
	touch $(scoredir)/gnomine.scores
	chown games.games $(scoredir)/samegnome.scores
	chmod 664 $(scoredir)/samegnome.scores

