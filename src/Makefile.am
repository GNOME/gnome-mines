bin_PROGRAMS = gnome-mines

resources.c: gnome-mines.gresource.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=$(srcdir) $(srcdir)/gnome-mines.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --generate-source $<

gnome_mines_SOURCES =	\
	config.vapi	\
	gnome-mines.vala \
	minefield.vala \
	minefield-view.vala \
	tile.vala \
	theme-selector-dialog.vala \
	resources.c

gnome_mines_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnome-mines\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	-w \
	$(GNOME_MINES_CFLAGS)

gnome_mines_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg librsvg-2.0 \
	--pkg pango \
	--pkg pangocairo \
	--pkg libgnome-games-support-1 \
	--pkg gee-0.8 \
	--target-glib $(GLIB_REQUIRED)

gnome_mines_LDADD = \
	$(GNOME_MINES_LIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

EXTRA_DIST = interface.ui \
             gnome-mines.css \
             gnome-mines.gresource.xml

-include $(top_srcdir)/git.mk
