pixmapdir = $(datadir)/pixmaps
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
        $(X_LIBS) $(x_libs)

EXTRA_DIST = flag.xpm mine.xpm face-cool.xpm face-sad.xpm face-smile.xpm face-win.xpm face-worried.xpm \
	     gnomine.desktop README AUTHORS

pixmap_DATA = flag.xpm mine.xpm face-cool.xpm face-sad.xpm face-smile.xpm face-win.xpm face-worried.xpm


install-data-local:
	$(mkinstalldirs) $(Gamesdir)
	$(INSTALL_DATA) $(srcdir)/gnomine.desktop $(datadir)/apps/Games/"Gnome Mines.desktop"
