# Pure logic shared by the docklet module and its unit tests. Kept separate so
# the test binary does not pull in the GTK panel or the resource bundle.
docklet_shelf_logic_sources = [
  'ShelfDirectoryLoader.vala',
  'ShelfEntry.vala',
  'ShelfPath.vala',
  'ShelfPreferences.vala',
  'ShelfStore.vala',
  'ShelfUtils.vala',
]

docklet_shelf_sources = docklet_shelf_logic_sources + [
  'ShelfDockItem.vala',
  'ShelfDocklet.vala',
  'ShelfItemView.vala',
  'ShelfPanel.vala',
  'ShelfTile.vala',
]

docklet_shelf_resources = gnome.compile_resources(
  'docky-shelf-resources',
  'shelf.gresource.xml',
  c_name: 'docky_shelf',
)

shared_module(
  'docklet-shelf',
  docklet_shelf_sources,
  docklet_shelf_resources,
  dependencies: [plank_dep, plank_base_dep],
  install: true,
  install_dir: docklets_dir,
)

# Unit tests live in this subdirectory so Meson can map the generated C files
# of the Vala sources correctly; tests/meson.build only registers them.
shelf_tests_bin = executable(
  'shelf-tests',
  docklet_shelf_logic_sources,
  'ShelfTest.vala',
  dependencies: [plank_dep, plank_base_dep],
  install: false,
)
