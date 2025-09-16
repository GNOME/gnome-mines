project ('gnome-mines', ['vala', 'c'],
         version: '49.0.1',
         license: 'GPLv3+',
         default_options: [
             'warning_level=1',
             'buildtype=debugoptimized',
         ],
         meson_version: '>= 0.59.0')

app_id = 'org.gnome.Mines'

gnome = import ('gnome')
i18n = import ('i18n')
cc = meson.get_compiler('c')

# Paths
mandir = join_paths (get_option ('prefix'), get_option ('mandir'))
localedir = join_paths (get_option ('prefix'), get_option ('localedir'))
gettext_package = 'gnome-mines'
datadir = join_paths (get_option ('prefix'), get_option ('datadir'))
pkgdatadir = join_paths (datadir, 'gnome-mines')
bindir = join_paths (get_option ('prefix'), get_option ('bindir'))

# Dependencies
glib_dep = dependency ('glib-2.0', version: '>= 2.40.0')
gee_dep = dependency ('gee-0.8')
gtk_dep = dependency ('gtk4', version: '>= 4.6')
adw_dep = dependency ('libadwaita-1', version: '>= 1.8.alpha')
librsvg_dep = dependency ('librsvg-2.0', version: '>=2.32.0')
libgnome_games_support = subproject ('libgnome-games-support',
	    		             default_options: 'superproject_name=gnome-mines')
libgnome_games_support_dep = libgnome_games_support.get_variable ('lggs_dependency')
libmath_dep = cc.find_library('m')

subdir ('po')
subdir ('data')
subdir ('help')
subdir ('src')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true
)

