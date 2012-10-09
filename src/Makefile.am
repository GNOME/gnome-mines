bin_PROGRAMS = gnome-mines

gnome_mines_SOURCES =	\
	config.vapi	\
	gnome-mines.vala \
	history.vala \
	minefield.vala \
	minefield-view.vala

gnome_mines_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnome-mines\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GNOME_MINES_CFLAGS)

gnome_mines_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg librsvg-2.0 \
	--pkg pango \
	--pkg pangocairo

gnome_mines_LDADD = \
	$(GNOME_MINES_LIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
