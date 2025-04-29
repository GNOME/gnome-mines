install_data (join_paths ('icons', 'hicolor', 'scalable', '@0@.svg'.format(app_id)),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))

install_data (join_paths ('icons', 'hicolor', 'symbolic', '@0@-symbolic.svg'.format(app_id)),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'symbolic', 'apps'))

install_data ('@0@.gschema.xml'.format(app_id),
              install_dir: join_paths (datadir, 'glib-2.0', 'schemas'))

foreach theme: [ 'default', 'bgcolors', 'classic', 'modern' ]
    foreach file: [ 'theme.css',
                    '1mines.svg', '2mines.svg', '3mines.svg', '4mines.svg', '5mines.svg', '6mines.svg', '7mines.svg', '8mines.svg',
                    'mine.svg', 'flag.svg', 'incorrect.svg', 'exploded.svg', 'maybe.svg' ]
        install_data (join_paths ('themes', theme, file), install_dir: join_paths (pkgdatadir, 'themes', theme))
    endforeach
endforeach


service_conf = configuration_data()
service_conf.set('bindir', bindir)

configure_file(
  input: '@0@.service.in'.format(app_id),
  output: '@0@.service'.format(app_id),
  install: true,
  install_dir: join_paths(datadir, 'dbus-1', 'services'),
  configuration: service_conf
)


desktop_file = i18n.merge_file (
                 input: '@0@.desktop.in'.format(app_id),
                 output: '@0@.desktop'.format(app_id),
                 install: true,
                 install_dir: join_paths (datadir, 'applications'),
                 po_dir: '../po',
                 type: 'desktop')

desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [
      desktop_file.full_path()
    ]
  )
endif


metainfo_file = i18n.merge_file (
                 input: '@0@.metainfo.xml.in'.format(app_id),
                 output: '@0@.metainfo.xml'.format(app_id),
                 install: true,
                 install_dir: join_paths (datadir, 'metainfo'),
                 po_dir: '../po')

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test(
    'validate-metainfo', appstreamcli,
    args: [
      'validate', '--no-net', '--explain', metainfo_file.full_path()
    ]
  )
endif

install_man ('gnome-mines.6')
