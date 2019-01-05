foreach size: [ '16x16', '22x22', '24x24', '32x32', '48x48', '256x256' ]
    install_data (join_paths ('icons', 'hicolor', size, '@0@.png'.format(app_id)),
                  install_dir: join_paths (datadir, 'icons', 'hicolor', size, 'apps'))
endforeach
install_data (join_paths ('icons', 'hicolor', 'scalable', '@0@-symbolic.svg'.format(app_id)),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))

install_data ('@0@.gschema.xml'.format(app_id),
              install_dir: join_paths (datadir, 'glib-2.0', 'schemas'))

foreach theme: [ 'default', 'bgcolors', 'classic' ]
    foreach file: [ 'theme.css',
                    '1mines.svg', '2mines.svg', '3mines.svg', '4mines.svg', '5mines.svg', '6mines.svg', '7mines.svg', '8mines.svg',
                    'mine.svg', 'flag.svg', 'incorrect.svg', 'exploded.svg', 'overmine.svg', 'maybe.svg' ]
        install_data (join_paths ('themes', theme, file), install_dir: join_paths (pkgdatadir, 'themes', theme))
    endforeach
endforeach

i18n.merge_file ('desktop-file',
                 input: '@0@.desktop.in'.format(app_id),
                 output: '@0@.desktop'.format(app_id),
                 install: true,
                 install_dir: join_paths (datadir, 'applications'),
                 po_dir: '../po',
                 type: 'desktop')

i18n.merge_file ('appdata-file',
                 input: '@0@.appdata.xml.in'.format(app_id),
                 output: '@0@.appdata.xml'.format(app_id),
                 install: true,
                 install_dir: join_paths (datadir, 'metainfo'),
                 po_dir: '../po')

install_man ('gnome-mines.6')
