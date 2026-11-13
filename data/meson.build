i18n.merge_file(
  input: 'plank.appdata.xml.in',
  output: 'plank.appdata.xml',
  po_dir: '../po',
  type: 'xml',
  install: true,
  install_dir: join_paths(data_dir, 'metainfo'),
)

install_data(
  'net.launchpad.plank.gschema.xml',
  install_dir: join_paths(data_dir, 'glib-2.0', 'schemas'),
)

plank_gschema_compile = gnome.compile_schemas(
  depend_files: files('net.launchpad.plank.gschema.xml'),
)

i18n.merge_file(
  input: 'net.launchpad.plank.desktop.in',
  output: 'net.launchpad.plank.desktop',
  po_dir: '../po',
  type: 'desktop',
  install: true,
  install_dir: join_paths(data_dir, 'applications'),
)

icons_dir = join_paths(get_option('datadir'), 'icons', 'hicolor')
icon_sizes = ['16x16', '22x22', '24x24', '32x32', '48x48', '64x64', '128x128', '256x256', '512x512']
icon_names = ['plank-studio.png', 'plank-studio-dark.png', 'plank-studio-light.png', 'plank-reloaded.png', 'plank.png']
foreach size : icon_sizes
  foreach name : icon_names
    install_data(
      join_paths('icons', size, name),
      install_dir: join_paths(icons_dir, size, 'apps'),
    )
  endforeach
endforeach

themes_dir = join_paths(pkgdata_dir, 'themes')
foreach theme : ['Default', 'Matte', 'Matte-Light', 'Minimal', 'Minimal-Light', 'Transparent']
  install_subdir(join_paths('themes', theme), install_dir: themes_dir)
endforeach

# Installation of Apport support files
enable_apport = get_option('enable-apport')
if enable_apport
  install_data(
    'apport/source_plank.py',
    install_dir: join_paths(get_option('datadir'), 'apport', 'package-hooks'),
  )
  install_data(
    'apport/plank-crashdb.conf',
    install_dir: join_paths(get_option('sysconfdir'), 'apport', 'crashdb.conf.d'),
  )
endif

