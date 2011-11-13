gsettings_in_file = org.gnome.gnomine.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

man_MANS = gnomine.6

pixmapdir   = $(datadir)/gnome-games/gnomine/pixmaps
pixmap_DATA = face-cool.svg face-sad.svg face-smile.svg face-win.svg 	\
	face-worried.svg \
	flag.svg flag-question.svg mine.svg bang.svg warning.svg

EXTRA_DIST = $(gsettings_in_file) \
             $(man_MANS) \
             $(pixmap_DATA)

Gamesdir = $(datadir)/applications
Games_in_files = gnomine.desktop.in.in
Games_DATA = $(Games_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

DISTCLEANFILES = $(Games_DATA) $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
