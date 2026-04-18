project('monody-hotcorners', 'vala', 'c')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk+-3.0'),
    dependency('gdk-3.0'),
    dependency('libxfconf-0'),
    dependency('x11'),
    meson.get_compiler('c').find_library('m', required : false),
]

executable('monody-hotcorner-service',
    'monody-hotcorner-service.vala',
    'xfconf.vapi',
    dependencies: dependencies,
    install: true,
    install_dir: get_option('bindir')
)

executable('monody-hotcorner-settings',
    'monody-hotcorner-settings.vala',
    'xfconf.vapi',
    dependencies: dependencies,
    install: true,
    install_dir: get_option('bindir')
)
