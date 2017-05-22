foreach size: [ '16x16', '22x22', '24x24', '32x32', '48x48' ]
    install_data (join_paths ('icons', 'hicolor', size, 'gnome-mines.png'),
                  install_dir: join_paths (datadir, 'icons', 'hicolor', size, 'apps'))
endforeach
install_data (join_paths ('icons', 'hicolor', 'scalable', 'gnome-mines-symbolic.svg'),
              install_dir: join_paths (datadir, 'icons', 'hicolor', size, 'apps'))
install_data ('flag-symbolic.svg',
              install_dir: join_paths (datadir, 'icons', 'hicolor', '16x16', 'actions'))

install_data ('org.gnome.mines.gschema.xml',
              install_dir: join_paths (datadir, 'glib-2.0', 'schemas'))
meson.add_install_script ('meson_compile_gschema.py')

foreach theme: [ 'default', 'bgcolors', 'classic' ]
    foreach file: [ 'theme.css',
                    '1mines.svg', '2mines.svg', '3mines.svg', '4mines.svg', '5mines.svg', '6mines.svg', '7mines.svg', '8mines.svg',
                    'mine.svg', 'flag.svg', 'incorrect.svg', 'exploded.svg', 'overmine.svg', 'maybe.svg' ]
        install_data (join_paths ('themes', theme, file), install_dir: join_paths (pkgdatadir, 'themes', theme))
    endforeach
endforeach

# Note the keywords explicitly listed to stop the icon field being translated
# https://bugs.launchpad.net/bugs/1624662
custom_target ('gnome-mines.desktop',
               output: 'gnome-mines.desktop',
               input: 'gnome-mines.desktop.in',
               command: [ msgfmt, '--desktop', '--keyword=Name', '--keyword=GenericName', '--keyword=Comment', '--keyword=Keywords', '--template', '@INPUT@', '-d', podir, '-o', '@OUTPUT@' ],
               install: true,
               install_dir: join_paths (datadir, 'applications'))

custom_target ('gnome-mines.appdata.xml',
               output: 'gnome-mines.appdata.xml',
               input: 'gnome-mines.appdata.xml.in',
               command: [ msgfmt, '--xml', '--template', '@INPUT@', '-d', podir, '-o', '@OUTPUT@' ],
               install: true,
               install_dir: join_paths (datadir, 'appdata'))

install_man ('gnome-mines.6')
