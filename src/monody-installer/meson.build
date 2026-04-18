project('monody-installer', 'vala', 'c')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk+-3.0'),
    dependency('gio-2.0'),
    dependency('vte-2.91'),
    dependency('timezonemap'),
]

sources = [
    'config.vala',
    'disk.vala',
    'engine.vala',
    'install_type.vala',
    'keymap.vala',
    'monody-installer.vala',
    'mountpoint.vala',
    'progress.vala',
    'summary.vala',
    'timezone.vala',
    'user.vala',
    'utils.vala',
    'welcome.vala',
]

executable('monody-installer',
    sources,
    'timezonemap.vapi',
    dependencies: dependencies,
    install: true,
    install_dir: get_option('bindir')
)
