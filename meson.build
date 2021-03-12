project ('gnome-mines', ['vala', 'c'],
         version: '40.0',
         license: 'GPLv3+',
         default_options: [
             'warning_level=1',
             'buildtype=debugoptimized',
         ],
         meson_version: '>= 0.37.1')

app_id = 'org.gnome.Mines'

gnome = import ('gnome')
i18n = import ('i18n')
cc = meson.get_compiler('c')

# Paths
mandir = join_paths (get_option ('prefix'), get_option ('mandir'))
localedir = join_paths (get_option ('prefix'), get_option ('localedir'))
datadir = join_paths (get_option ('prefix'), get_option ('datadir'))
pkgdatadir = join_paths (datadir, 'gnome-mines')

# Dependencies
glib_dep = dependency ('glib-2.0', version: '>= 2.40.0')
gee_dep = dependency ('gee-0.8')
gtk_dep = dependency ('gtk+-3.0', version: '>= 3.24')
librsvg_dep = dependency ('librsvg-2.0', version: '>=2.32.0')
libgnome_games_support_dep = dependency ('libgnome-games-support-1', version: '>= 1.7.1')
libmath_dep = cc.find_library('m')

subdir ('po')
subdir ('data')
subdir ('help')
subdir ('src')
meson.add_install_script ('build-aux/meson_post_install.py')
