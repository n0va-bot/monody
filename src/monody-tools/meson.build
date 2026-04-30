project('monody-tools', 'vala', 'c')

gtk_dep = dependency('gtk+-3.0')
vte_dep = dependency('vte-2.91')
x11_dep = dependency('x11')
glib_dep = dependency('glib-2.0')
gio_dep = dependency('gio-2.0')

executable('monody-welcome',
    'monody-welcome.vala',
    dependencies: [gtk_dep, vte_dep],
    install: true,
    install_dir: get_option('bindir')
)

executable('monody-updater',
    'monody-updater.vala',
    dependencies: [gtk_dep, vte_dep, x11_dep],
    install: true,
    install_dir: get_option('bindir')
)
