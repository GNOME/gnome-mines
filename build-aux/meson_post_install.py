#!/usr/bin/env python3

import os
import subprocess

datadir = os.path.join(os.environ['MESON_INSTALL_PREFIX'], 'share')

if not os.environ.get('DESTDIR'):
    print('Compiling gsettings schemas...')
    subprocess.call(['glib-compile-schemas', os.path.join(datadir, 'glib-2.0', 'schemas')])
    print('Updating icon cache...')
    subprocess.call(['gtk-update-icon-cache', os.path.join(datadir, 'icons', 'hicolor')])
    print('Updating desktop database...')
    subprocess.call(['update-desktop-database', os.path.join(datadir, 'applications')])
    