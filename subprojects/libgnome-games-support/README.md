# libgnome-games-support 
A small library intended for internal use by GNOME Games,
but it may be used by others.

## Using libgnome-games-support
Before version 3.0, libgnome-games-support was shipped like a normal library,
but now it is a copylib that is used as a meson subproject.

### Using as a meson subproject
1. In your meson.build, declare a dependency on libgnome-games-support:

```
libgnome_games_support = subproject ('libgnome-games-support',
                                     default_options: 'superproject_name=gnome-mines')

libgnome_games_support_dep = libgnome_games_support.get_variable ('lggs_dependency')

```

And set the ``superproject_name`` (here it is ``gnome-mines``) with the name of your project. 

2. Create ``subprojects/libgnome-games-support.wrap``, it should contain

```
[wrap-git]
directory = libgnome-games-support
url = https://gitlab.gnome.org/GNOME/libgnome-games-support.git
revision = 3.0.0
depth = 1

```

### libgnome-games-support documentation

You either read the comments in the source code or generate documentation for yourself with:

``$ valadoc --package-name=libgnome-games-support --package-version=3.0 --force --pkg=gtk4 --pkg=libadwaita-1 --pkg=gee-0.8 -o docs games/config.vapi games/*.vala games/scores/*.vala``
