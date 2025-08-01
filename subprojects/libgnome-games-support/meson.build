project(
    'libgnome-games-support', ['vala', 'c'],
    version: '3.0.0',
    license: 'LGPLv3+',
    meson_version: '>= 1.1',
)

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

adw_dependency = dependency ('libadwaita-1', version: '>= 1.0')
gee_dependency = dependency('gee-0.8', version: '>= 0.14.0')
gio_dependency = dependency('gio-2.0', version: '>= 2.44.0')
glib_dependency = dependency('glib-2.0', version: '>= 2.44.0')
gtk_dependency = dependency('gtk4', version: '>= 4.2.0')

includedir = join_paths(get_option('prefix'), get_option('includedir'))
localedir = join_paths(get_option('prefix'), get_option('localedir'))
gettext_package = get_option('superproject_name') + '_' + meson.project_name()

subdir('po')
subdir('games')

lggs_dependency = declare_dependency(
    link_with: lggs,
    include_directories: include_directories('games/'),
)

subdir('tests')