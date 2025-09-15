includesubdir = get_option('superproject_name') + '_gnome-games-support'

lggs_interface_deps = [
    adw_dependency,
    gee_dependency,
    gio_dependency,
    glib_dependency,
    gtk_dependency,
]

lggs = static_library('gnome-games-support-3',
    [
        'config.vapi',
        'gridframe.vala',
        'theme-selector-dialog.vala',
        'scores/category.vala',
        'scores/context.vala',
        'scores/dialog.vala',
        'scores/score.vala',
    ],
    c_args: [
        '-w',
        '-DGETTEXT_PACKAGE="@0@"'.format (gettext_package),
        '-DLOCALEDIR="@0@"'.format (localedir),
    ],
    vala_header: 'libgnome-games-support.h',
    dependencies: lggs_interface_deps,
)
