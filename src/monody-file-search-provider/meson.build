project('monody-file-search-provider', 'vala', 'c')

dependencies = [
    dependency('glib-2.0'),
    dependency('gio-2.0'),
    dependency('gtk+-3.0'),
    dependency('libxfconf-0'),
]

executable('monody-file-search-provider',
    'monody-file-search-provider.vala',
    dependencies: dependencies,
    install: true,
    install_dir: get_option('bindir')
)

executable('monody-file-search-settings',
    'monody-file-search-settings.vala',
    dependencies: dependencies,
    install: true,
    install_dir: get_option('bindir')
)
