Gamesdir = $(datadir)/applications

SUBDIRS = help

INCLUDES = \
	-I$(top_srcdir)/libgames-support		\
	$(WARN_CFLAGS)					\
	$(GNOME_GAMES_CFLAGS)				\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\"	\
	-DDATADIR=\""$(datadir)"\" 

bin_PROGRAMS = gnomine

gnomine_SOURCES =	\
	gnomine.c	\
	minefield.h	\
	minefield.c

gnomine_LDADD = \
	../libgames-support/libgames-support.la \
	$(GNOME_GAMES_LIBS)

schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_in_files = gnomine.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

pixmapdir   = $(datadir)/pixmaps/gnomine/
pixmap_DATA = face-cool.svg face-sad.svg face-smile.svg face-win.svg 	\
	face-worried.svg \
	flag.svg flag-question.svg mine.svg bang.svg warning.svg

EXTRA_DIST = README AUTHORS \
	$(schema_in_files) $(pixmap_DATA)

Games_in_files = gnomine.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

SCOREFILES = Small Medium Large Custom

install-data-local:
if GCONF_SCHEMAS_INSTALL
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(top_builddir)/gnomine/$(schema_DATA)
endif
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	## Change the names of the high score files, unless the local user has 
	## beaten us to it.
	-if [ -f $(DESTDIR)$(scoredir)/gnomine.Tiny.scores -a ! -f $(DESTDIR)$(scoredir)/gnomine.Small.scores ]; then mv -f $(DESTDIR)$(scoredir)/gnomine.Tiny.scores $(DESTDIR)$(scoredir)/gnomine.Small.scores  ; fi
	-if [ -f $(DESTDIR)$(scoredir)/gnomine.Biiiig.scores -a ! -f $(DESTDIR)$(scoredir)/gnomine.Large.scores ]; then mv -f $(DESTDIR)$(scoredir)/gnomine.Biiiig.scores $(DESTDIR)$(scoredir)/gnomine.Large.scores  ; fi
	-for i in ${SCOREFILES} ; do \
	   touch $(DESTDIR)$(scoredir)/gnomine.$$i.scores; \
	   chown $(scores_user):$(scores_group) $(DESTDIR)$(scoredir)/gnomine.$$i.scores; \
	   chmod 664 $(DESTDIR)$(scoredir)/gnomine.$$i.scores; \
	 done
	-if test "x$(setgid)" = "xtrue"; then chgrp $(scores_group) $(DESTDIR)$(bindir)/gnomine && chmod 2555 $(DESTDIR)$(bindir)/gnomine ; fi

DISTCLEANFILES = $(Games_DATA) $(schema_DATA)
