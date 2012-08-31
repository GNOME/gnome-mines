bin_PROGRAMS = gnomine

gnomine_SOURCES =	\
	config.vapi	\
	gnomine.vala \
	history.vala \
	minefield.vala \
	minefield-view.vala

gnomine_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnomine\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GTK_CFLAGS) \
	$(RSVG_CFLAGS)

gnomine_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg librsvg-2.0 \
	--pkg pango \
	--pkg pangocairo

gnomine_LDADD = \
	$(GTK_LIBS) \
	$(RSVG_LIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
