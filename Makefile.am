scoredir=$(localstatedir)/games
Gamesdir = $(datadir)/applications

SUBDIRS = help

INCLUDES = \
	-I$(top_srcdir)/libgames-support		\
	$(WARN_CFLAGS)					\
	$(GNOME_GAMES_CFLAGS)				\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\"	\
	-DDATADIR=\""$(datadir)"\"		   \
	-DG_DISABLE_DEPRECATED -DGDK_DISABLE_DEPRECATED \
	-DGTK_DISABLE_DEPRECATED -DGNOME_DISABLE_DEPRECATED

bin_PROGRAMS = gnomine

gnomine_SOURCES =	\
	gnomine.c	\
	minefield.h	\
	minefield.c

gnomine_LDADD = \
	$(GNOME_GAMES_LIBS) \
	../libgames-support/libgames-support.la \
	$(INTLLIBS)

schemadir   = $(sysconfdir)/gconf/schemas
schema_in_files = gnomine.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

pixmapdir   = $(datadir)/pixmaps/gnomine/
pixmap_DATA = face-cool.xpm face-sad.xpm face-smile.xpm face-win.xpm 	\
	face-worried.xpm

EXTRA_DIST = gnomine.desktop.in README AUTHORS				\
	$(schema_DATA) $(pixmap_DATA) flag.xpm mine.xpm question.xpm

Games_in_files = gnomine.desktop.in
Games_DATA = $(Games_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

install-data-local:
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(srcdir)/$(schema_DATA)
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
	-chgrp games $(DESTDIR)$(bindir)/gnomine && chmod 2555 $(DESTDIR)$(bindir)/gnomine

CLEANFILES = $(Games_DATA) $(schema_DATA)
