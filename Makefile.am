SUBDIRS = icons

if BUILD_HELP
SUBDIRS += help
endif

bin_PROGRAMS = gnomine

gnomine_SOURCES =	\
	gnomine.c	\
	minefield.h	\
	minefield.c

gnomine_CPPFLAGS = \
	-I$(top_srcdir) \
	$(AM_CPPFLAGS)

gnomine_CFLAGS = \
	$(GTK_CFLAGS) \
	$(AM_CFLAGS)

gnomine_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GTK_LIBS)

if HAVE_GNOME
gnomine_CFLAGS += $(GNOME_CFLAGS)
gnomine_LDADD += $(GNOME_LIBS)
endif

if HAVE_RSVG
gnomine_CFLAGS += $(RSVG_CFLAGS)
gnomine_LDADD += $(RSVG_LIBS)
endif

if WITH_GTHREAD
gnomine_CFLAGS += $(GHTREAD_CFLAGS)
gnomine_LDADD += $(GTHREAD_LIBS)
endif

schema_in_files = gnomine.schemas.in
if HAVE_GNOME
schemadir = $(GCONF_SCHEMA_FILE_DIR)
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
endif

@INTLTOOL_SCHEMAS_RULE@

man_MANS = gnomine.6

pixmapdir   = $(datadir)/gnome-games/gnomine/pixmaps
pixmap_DATA = face-cool.svg face-sad.svg face-smile.svg face-win.svg 	\
	face-worried.svg \
	flag.svg flag-question.svg mine.svg bang.svg warning.svg

EXTRA_DIST = README AUTHORS \
             $(schema_in_files) \
             $(man_MANS) \
             $(pixmap_DATA)

Gamesdir = $(datadir)/applications
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

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/gnomine && chmod 2555 $(DESTDIR)$(bindir)/gnomine ;\
	fi

DISTCLEANFILES = $(Games_DATA) $(schema_DATA)

-include $(top_srcdir)/git.mk
