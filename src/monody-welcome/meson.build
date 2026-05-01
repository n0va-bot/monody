project('monody-welcome', 'vala', 'c')

gtk_dep = dependency('gtk+-3.0')
vte_dep = dependency('vte-2.91')

executable('monody-welcome',
    'monody-welcome.vala',
    dependencies: [gtk_dep, vte_dep],
    install: true,
    install_dir: get_option('bindir')
)