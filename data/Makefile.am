SUBDIRS = icons

gsettings_SCHEMAS = org.gnome.mines.gschema.xml
@GSETTINGS_RULES@

man_MANS = gnome-mines.6

pixmapdir   = $(pkgdatadir)
pixmap_DATA = mine.svg bang.svg warning.svg \
            1mine.svg 2mines.svg 3mines.svg 4mines.svg \
            5mines.svg 6mines.svg 7mines.svg 8mines.svg \
            flag-symbolic.svg flag.svg flag-question.svg

gnome-mines.css: gnome-mines.css.in Makefile
	$(AM_V_GEN) sed -e "s|\@pkgdatadir\@|$(pkgdatadir)|" $< > $@

cssdir = $(pkgdatadir)
css_in_files = gnome-mines.css.in
css_DATA = $(css_in_files:.css.in=.css)

uidir = $(pkgdatadir)
ui_DATA = interface.ui

desktopdir = $(datadir)/applications
desktop_in_files = gnome-mines.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_in_files = gnome-mines.appdata.xml.in
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
@INTLTOOL_XML_RULE@

EXTRA_DIST = \
	     $(appdata_in_files) \
             $(gsettings_SCHEMAS) \
             $(desktop_in_files) \
             $(man_MANS) \
             $(pixmap_DATA) \
             $(css_in_files) \
             $(ui_DATA)

CLEANFILES = \
	$(appdata_DATA)	\
	$(desktop_DATA) \
	$(css_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
