foreach size: [ '16x16', '22x22', '24x24', '32x32', '48x48' ]
    install_data (join_paths ('icons', 'hicolor', size, 'gnome-mines.png'),
                  install_dir: join_paths (datadir, 'icons', 'hicolor', size, 'apps'))
endforeach
install_data (join_paths ('icons', 'hicolor', 'scalable', 'gnome-mines-symbolic.svg'),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))
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

i18n.merge_file ('desktop-file',
                 input: 'gnome-mines.desktop.in',
                 output: 'gnome-mines.desktop',
                 install: true,
                 install_dir: join_paths (datadir, 'applications'),
                 po_dir: '../po',
                 type: 'desktop')

i18n.merge_file ('appdata-file',
                 input: 'gnome-mines.appdata.xml.in',
                 output: 'gnome-mines.appdata.xml',
                 install: true,
                 install_dir: join_paths (datadir, 'metainfo'),
                 po_dir: '../po')

install_man ('gnome-mines.6')
