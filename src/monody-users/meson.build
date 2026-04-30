project('monody-users', 'vala', 'c')

gtk_dep = dependency('gtk+-3.0')
x11_dep = dependency('x11')

executable('monody-users',
    'monody-users.vala',
    dependencies: [gtk_dep, x11_dep],
    install: true,
    install_dir: get_option('bindir')
)
