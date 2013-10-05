SUBDIRS = icons

gsettings_SCHEMAS = org.gnome.mines.gschema.xml
@GSETTINGS_RULES@

man_MANS = gnome-mines.6

pixmapdir   = $(datadir)/gnome-mines
pixmap_DATA = face-cool.svg face-sad.svg face-smile.svg face-win.svg \
	face-worried.svg \
	flag.svg flag-question.svg mine.svg bang.svg warning.svg

desktopdir = $(datadir)/applications
desktop_in_files = gnomine.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_DATA = gnome-mines.appdata.xml

EXTRA_DIST = \
	     $(appdata_DATA) \
             $(gsettings_SCHEMAS) \
             $(desktop_in_files) \
             $(man_MANS) \
             $(pixmap_DATA)

CLEANFILES = $(desktop_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
