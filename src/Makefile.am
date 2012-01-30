bin_PROGRAMS = gnomine

gnomine_SOURCES =	\
	config.vapi	\
	gnomine.vala \
	minefield.vala \
	minefield-view.vala

gnomine_CFLAGS = \
	-I$(top_srcdir)/libgames-support \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnomine\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GTK_CFLAGS)

gnomine_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg pango \
	--pkg pangocairo \
	--vapidir $(top_srcdir)/libgames-support \
	--pkg GnomeGamesSupport-1.0

gnomine_LDADD = \
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GTK_LIBS)

if HAVE_RSVG
gnomine_CFLAGS += $(RSVG_CFLAGS)
gnomine_LDADD += $(RSVG_LIBS)
endif

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/gnomine && chmod 2555 $(DESTDIR)$(bindir)/gnomine ;\
	fi

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
