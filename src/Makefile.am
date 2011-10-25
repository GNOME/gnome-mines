SUBDIRS = data icons src

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

gsettings_in_file = org.gnome.gnomine.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

man_MANS = gnomine.6

pixmapdir   = $(datadir)/gnome-games/gnomine/pixmaps
pixmap_DATA = face-cool.svg face-sad.svg face-smile.svg face-win.svg 	\
	face-worried.svg \
	flag.svg flag-question.svg mine.svg bang.svg warning.svg

EXTRA_DIST = README AUTHORS \
             $(gsettings_in_file) \
             $(man_MANS) \
             $(pixmap_DATA)

Gamesdir = $(datadir)/applications
Games_in_files = gnomine.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

SCOREFILES = Small Medium Large Custom

install-data-local:
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

DISTCLEANFILES = $(Games_DATA) $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
