SUBDIRS = icons themes

gsettings_SCHEMAS = org.gnome.mines.gschema.xml
@GSETTINGS_RULES@

man_MANS = gnome-mines.6

icon_symbolicdir=$(datadir)/icons/hicolor/16x16/actions
icon_symbolic_DATA=flag-symbolic.svg

desktopdir = $(datadir)/applications
desktop_in_files = gnome-mines.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

$(desktop_DATA): $(desktop_in_files)
	$(AM_V_GEN) $(MSGFMT) --desktop --template $< -d $(top_srcdir)/po -o $@

appstream_in_files = gnome-mines.appdata.xml.in
appstream_XML = $(appstream_in_files:.xml.in=.xml)
@APPSTREAM_XML_RULES@

$(appstream_XML): $(appstream_in_files)
	$(AM_V_GEN) $(MSGFMT) --xml --template $< -d $(top_srcdir)/po -o $@

EXTRA_DIST = \
             $(appstream_in_files) \
             $(gsettings_SCHEMAS) \
             $(desktop_in_files) \
             $(man_MANS) \
             $(icon_symbolic_DATA) \
             $(css_DATA) \
             $(ui_DATA)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA)

check-local: $(desktop_DATA) \
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

DISTCHECK_CONFIGURE_FLAGS = --enable-appdata-check

-include $(top_srcdir)/git.mk
