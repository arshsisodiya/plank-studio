# Plank Studio

[![GitHub Release](https://img.shields.io/github/v/release/zquestz/plank-reloaded)](https://github.com/zquestz/plank-reloaded/releases) [![Crowdin](https://badges.crowdin.net/plank-reloaded/localized.svg)](https://crowdin.com/project/plank-reloaded)

## What Is Plank Studio?

**Plank Studio** is a fork of **Plank Reloaded**, which is a fork of the original **[Plank](https://launchpad.net/plank)** project. It provides an elegant, feature-rich, and lightning-fast dock system designed specifically for X11 desktop environments (Cinnamon, MATE, Xfce, KDE, and more). Wayland is not supported at this time.

Originally built as a lightweight, barebones dock application ("the simplest dock on the planet"), Plank Studio significantly expands upon this foundation. It transforms the dock into a versatile, modern desktop dock system — introducing multi-dock management, collapsible dock stacks, native file and folder integration, a new Shelf workspace docklet, smart square icon rounding, customizable hover-to-zoom effects, and rich window previews — all while retaining the buttery-smooth performance, minimal resource usage, and clean aesthetics of the original Plank.

![Plank Studio on Linux Mint](screenshots/plank-reloaded-mint.webp)

---

## Key Features & New Improvements

Plank Studio retains the core purpose of an intuitive desktop dock while introducing a comprehensive suite of powerful features and customization options:

### 1. Multiple Independent Docks
Run multiple docks on a single desktop simultaneously from a single process:
- **Up to 8 Independent Docks**: Create, duplicate, rename, enable, disable, or delete docks in one place.
- **Independent Placement**: Position docks on any screen edge (**Bottom**, **Top**, **Left**, or **Right**) and choose alignment (**Start**, **Center**, **End**, or **Fill**).
- **Collision Avoidance & Overlap Prevention**: The **"Keep docks from overlapping"** feature automatically calculates collision offsets and nudges adjacent docks apart when they share the same monitor edge.
- **Multi-Monitor & Active Display Tracking**: Place docks on specific monitors or enable **"On Active Display"** so docks dynamically follow the mouse cursor between monitors (with `killall -USR1 plank` shortcut support).
- **Per-Dock Independence**: Each dock retains its own launchers folder, item list, visual theme, hiding behavior, effects, and docklets.

### 2. Redesigned Preferences Hub
The Preferences window has been completely reimagined for effortless multi-dock management:
- **Persistent Dock Sidebar**: Easily switch between configuring different docks with a single click.
- **Dock Management Actions**: Quick-access header menu to rename, duplicate, and delete the active dock, with a dedicated **Add Dock** button.
- **Well-Organized Settings Tabs**:
  - **Appearance**: Theme selection, icon sizing (16–128 px), floating dock gap size (0–200 px), item alignment, and self-dock item visibility.
  - **Position**: Screen edge, monitor targeting, active display tracking, alignment offset (-100% to 100%), and area modes.
  - **Behaviour**: Hiding modes (Intelligent, Auto-hide, Dodge Maximized, Window Dodge, Dodge Active), hide/unhide delays, pressure reveal, and workspace restrictions.
  - **Effects**: Dedicated configuration for hover-to-zoom controls, collapsible stack mode options, and square icon rounding sliders.
  - **Items**: Granular list view to manage, reorder, lock, anchor, and delete pinned applications, files, and folders.
  - **Docklets**: Browse and add built-in docklets to the active dock with live configuration.
- **Toggle Dock Item**: Includes an explicit **"Show Plank Item"** toggle to display or hide the dock's own launcher icon.

### 3. Hideable / Collapsible Dock (Stackable Mode)
A space-saving collapsible dock mode designed for ultra-clean desktops:
- **Compact Single-Icon Stack**: Collapse an entire dock into a compact, single-icon stack featuring a sleek collapse handle and an item counter badge.
- **Smooth Staggered Cascade Animation**: Clicking the stack smoothly expands all items outward using customized cubic-bezier easing curves.
- **Directional Expansion**: Expand dock items in any of four directions: **Up**, **Down**, **Left**, or **Right** to fit any desktop edge or orientation.
- **Fine-Grained Controls**:
  - **Animation Speed**: Adjustable expand/collapse duration (100 ms to 800 ms).
  - **Item Spacing**: Configurable expansion padding (0 px to 48 px).
- **Smart Interactions**: Auto-expands when dragging items over the collapsed stack and automatically collapses when clicking outside.

### 4. Smart Square Icon Rounding
Eliminate mismatched, boxy icons and achieve visual harmony across diverse icon themes:
- **Automatic Edge Detection**: Algorithmic alpha-threshold analysis detects sharp square-cornered icons (including full-bleed designs and icons with transparent padding).
- **Preserves Existing Shapes**: Leaves already-rounded icons, circular icons, separators, and custom docklet shapes untouched.
- **Configurable Roundness**: Adjust corner radius between **4% and 30%** (default 10%) per dock.
- **Optimized Performance**: Features per-item and per-size surface caching with full HiDPI / device-scale preservation.

### 5. Customizable Hover-to-Zoom Effect
Give your dock fluid, interactive visual feedback on mouse hover:
- **Dedicated Effects Page**: Configure zoom behavior independently for each dock.
- **Toggle Zoom**: Easily turn the zoom effect on or off.
- **Magnification Scaling**: Smoothly adjust icon magnification from **100% up to 400%**.

### 6. Granular Running Application Visibility
Take total control over how running applications are represented on each dock:
- **Show Newly Opened Applications**: Toggle whether applications opened after startup automatically appear as unpinned dock items.
- **Only Show Pinned Applications**: Restrict a dock exclusively to pinned favorites — ideal for dual-dock setups where one dock acts as a fixed launcher and another tracks active tasks.
- **Restrict to Workspace**: Only show application windows active on the current virtual desktop.
- **Bring to Current Workspace**: Option to pull windows from other workspaces onto the current desktop upon activation.

### 7. Desktop Drag-and-Drop Management
Managing dock items is faster and more intuitive:
- **Direct Drag-and-Drop**: Drag `.desktop` application launchers, files, and directories from your desktop or file manager straight onto any dock.
- **Live Insertion Feedback**: Visual drop target indicators show exact placement while dragging.
- **Expand-on-Hover**: Dragging items over a collapsed stack automatically reveals the dock so you can drop items precisely where you want.

### 8. Native File & Folder Support
Expand your dock beyond traditional application shortcuts:
- **Pin Files & Folders**: Directly pin documents, text files, media, scripts, and directories onto any dock.
- **Direct Opening**: Launch pinned files and folders instantly using the system's default applications.
- **Edge Anchoring**: Anchor files (`anchor-files`) and docklets (`anchor-docklets`) to the edges of the dock independently, maintaining a clean visual separation between apps and documents.

### 9. New "Shelf" Docklet – Integrated File & Folder Workspace
A powerful new docklet designed for fast file and folder staging and access:
- **Temporary Staging Area**: Collect files and folders by dragging them onto the Shelf icon or open panel without copying, moving, or altering original files.
- **Adaptive Translucent Panel**: Floats adjacent to the Shelf docklet, adapting automatically to bottom, top, left, or right dock placements.
- **In-Panel Folder Hierarchy Browsing**: Navigate through nested directory structures directly inside the Shelf panel using clickable breadcrumbs and back navigation.
- **Grid and List Views**: View collected files and folders in a clean icon grid or detailed list view.
- **Instant Launch & Previews**: Launch files in default applications, preview file states, and clear or remove entries whenever needed.

### 10. Rich Window Previews
Preview open application windows directly from the dock:
- **Hover Previews**: Hovering over running applications displays live window thumbnails along with window titles.
- **Focus & Close Controls**: Click any preview to bring that window into immediate focus, or click the inline close button to dismiss it.
- **Minimized Window Capture**: Displays thumbnails for minimized windows when supported by the window manager (with fallback to cached thumbnail or app icon).
- **Customizable Timing & Sizing**: Adjust preview delay (0 to 2500 ms) and thumbnail size (64 to 640 px).

### 11. Performance, Smoothness & Stability
Refined under-the-hood architecture for maximum reliability and responsiveness:
- **High-Performance Cairo Rendering**: Subpixel item and shadow rendering avoids Xlib surface churn and flicker during resize and expand animations.
- **Crash Prevention**: Comprehensive guards across X11 GenericEvent filtering, monitor changes, and widget lifecycles prevent crashes during rapid desktop events.
- **Empty-Space Context Menus**: Right-clicking empty dock space reliably opens dock settings and context actions without signal disconnection.
- **Focused Dialogs**: Preferences and About dialogs open reliably in front of active windows.

### 12. Modern Visual Identity
- **Updated Branding**: Redesigned modern application icon reflecting Plank Studio's evolution while preserving the recognizable visual identity of the Plank family.

### 13. Rich Docklet Ecosystem
Plank Studio includes a comprehensive collection of built-in docklets:
- **Shelf**: Quick file/folder collection, navigation, and staging.
- **Applications**: Quick desktop application launcher menu.
- **Battery**: Real-time battery status with modern UPower integration.
- **Clock**: Digital clock display with an interactive pop-up calendar.
- **Clippy**: Clipboard history manager supporting text and image history.
- **Desktop**: Instant "Show Desktop" toggle.
- **Notifications**: Displays system notifications right on the dock.
- **Separator**: Clean dividers to visually group dock items.
- **Trash**: Trash docklet with drag-to-delete and quick empty actions.
- **Workspaces**: Visual graphical workspace pager and switcher.
- **Third-Party Docklet Support**: Full API compatibility for custom third-party docklets.

---

## Themes

Plank Studio ships with six built-in themes. You can switch themes in **Preferences → Appearance → Theme**.

### Default
![Default Theme](screenshots/default.webp)

### Matte
![Matte Theme](screenshots/matte.webp)

### Matte Light
![Matte Light Theme](screenshots/matte-light.webp)

### Minimal
![Minimal Theme](screenshots/minimal.webp)

### Minimal Light
![Minimal Light Theme](screenshots/minimal-light.webp)

### Transparent
![Transparent Theme](screenshots/transparent.webp)

### GTK Themes
Plank Studio also supports GTK themes. To use one, install it and set it as your default theme, then select **Gtk+** as the Plank Studio theme in preferences.

Here is a list of themes known to support Plank docks:
- [Celestial](https://github.com/zquestz/celestial-gtk-theme)
- [Matcha](https://github.com/zquestz/Matcha-gtk-theme)
- [Semabe](https://github.com/sewbej/Plank-Themes)
- [WhiteSur](https://github.com/vinceliuice/WhiteSur-gtk-theme)

---

## Installation

Expand your distribution below for package instructions or steps to build from source with required dependencies.

<details markdown="1">
<summary><strong>Arch Linux</strong></summary>

```bash
yay -S plank-reloaded-git
```

</details>

<details markdown="1">
<summary><strong>Linux Mint / Ubuntu (Noble Numbat)</strong></summary>

#### Option 1: Using the PPA (Recommended)

```bash
# Add the repository
curl -fsSL https://zquestz.github.io/ppa/ubuntu/KEY.gpg | sudo gpg --dearmor -o /usr/share/keyrings/zquestz-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/zquestz-archive-keyring.gpg] https://zquestz.github.io/ppa/ubuntu ./" | sudo tee /etc/apt/sources.list.d/zquestz.list
sudo apt update

# Install Plank Studio
sudo apt install plank-reloaded
```

#### Option 2: Building from Source

```bash
# Remove old plank versions to prevent library conflicts
sudo apt remove plank libplank-common libplank1

# Install required dependencies
sudo apt install build-essential pkg-config git meson ninja-build valac gettext cmake desktop-file-utils libxml2-utils libgtk-3-dev libgee-0.8-dev libgnome-menu-3-dev libbamf3-dev libwnck-3-dev libcanberra-dev libdbusmenu-glib-dev libdbusmenu-gtk3-dev libxi-dev libxfixes-dev bamfdaemon

# Clone the repository
git clone https://github.com/zquestz/plank-reloaded.git
cd plank-reloaded

# Build and install
meson setup --prefix=/usr build
meson compile -C build
sudo meson install -C build
```

</details>

<details markdown="1">
<summary><strong>LMDE / Debian (Bookworm)</strong></summary>

#### Option 1: Using the PPA (Recommended)

```bash
# Add the repository
curl -fsSL https://zquestz.github.io/ppa/debian/KEY.gpg | sudo gpg --dearmor -o /usr/share/keyrings/zquestz-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/zquestz-archive-keyring.gpg] https://zquestz.github.io/ppa/debian ./" | sudo tee /etc/apt/sources.list.d/zquestz.list
sudo apt update

# Install Plank Studio
sudo apt install plank-reloaded
```

#### Option 2: Building from Source

```bash
# Remove old plank versions
sudo apt remove plank libplank-common libplank1

# Install required dependencies
sudo apt install build-essential pkg-config git meson ninja-build valac gettext cmake desktop-file-utils libxml2-utils libgtk-3-dev libgee-0.8-dev libgnome-menu-3-dev libbamf3-dev libwnck-3-dev libcanberra-dev libdbusmenu-glib-dev libdbusmenu-gtk3-dev libxi-dev libxfixes-dev bamfdaemon

# Clone the repository
git clone https://github.com/zquestz/plank-reloaded.git
cd plank-reloaded

# Build and install
meson setup --prefix=/usr build
meson compile -C build
sudo meson install -C build
```

</details>

<details markdown="1">
<summary><strong>Fedora</strong></summary>

Plank Studio works on Fedora when running in X11 mode.

#### Option 1: Using RPM Packages
Download RPM packages from the [Releases](https://github.com/zquestz/plank-reloaded/releases) page:

```bash
sudo dnf install ./plank-reloaded-*.rpm
```

#### Option 2: Building from Source

```bash
# Set X11 backend environment
export GDK_BACKEND=x11
export XDG_SESSION_TYPE=x11

# Install required dependencies
sudo dnf install git meson ninja-build valac clang cmake libgnome-devel libxml2-devel gnome-menus-devel libgee libgee-devel libdbusmenu-gtk3-devel libdbusmenu-gtk3 libwnck3 libwnck3-devel libcanberra-devel bamf bamf-devel bamf-daemon

# Clone the repository
git clone https://github.com/zquestz/plank-reloaded.git
cd plank-reloaded

# Build and install
meson setup --prefix=/usr build
meson compile -C build
sudo meson install -C build
```

</details>

<details markdown="1">
<summary><strong>openSUSE</strong></summary>

A community package is available at:
[https://build.opensuse.org/package/show/home:asdhio/plank](https://build.opensuse.org/package/show/home:asdhio/plank)

</details>

<details markdown="1">
<summary><strong>FreeBSD</strong></summary>

Plank Studio is available in the FreeBSD Ports Collection:

#### Using pkg (Binary Package)
```bash
pkg install x11/plank
```

#### Using Ports
```bash
cd /usr/ports/x11/plank
make install clean
```

</details>

<details markdown="1">
<summary><strong>Nix</strong></summary>

A Nix flake is available at [./flake.nix](./flake.nix).

#### Running with Flakes
```sh
nix run github:zquestz/plank-reloaded
```

#### Building with Nix
```sh
nix build github:zquestz/plank-reloaded
```

The built executable will be located at `./result/bin/plank`.

</details>

---

## Frequently Asked Questions (FAQ)

<details markdown="1">
<summary><strong>Can I use Plank Studio on Wayland?</strong></summary>

No. Plank Studio is designed for X11 desktop environments only. Wayland is not supported at this time.
</details>

<details markdown="1">
<summary><strong>How do I access Plank Studio preferences?</strong></summary>

There are three easy ways to open Preferences:
1. **Right-Click Empty Space**: Right-click on any empty space of the dock and select **Preferences**.
2. **Ctrl + Right-Click**: Hold the <kbd>Ctrl</kbd> key while right-clicking anywhere on the dock.
3. **Plank Dock Item**: If **"Show Plank Item"** is enabled in Appearance preferences, right-click the Plank Studio icon and click **Preferences**.
</details>

<details markdown="1">
<summary><strong>How do I create and manage multiple docks?</strong></summary>

Open **Preferences**. In the sidebar on the left:
- Click **+ Add Dock** to create a new dock.
- Click on any dock in the sidebar to configure its settings.
- Use the header menu next to the dock name to **Rename**, **Duplicate**, or **Delete** the dock.
- Enable or disable docks using their toggle switch.

Enable **"Keep docks from overlapping"** to automatically prevent multiple docks on the same screen edge from overlapping.
</details>

<details markdown="1">
<summary><strong>How do I use Collapsible Stack Mode?</strong></summary>

1. Open **Preferences → Effects**.
2. Toggle on **Enable Stackable Mode**.
3. Choose your preferred **Stack Expansion Direction** (Up, Down, Left, or Right).
4. Optionally adjust **Animation Speed** and **Item Spacing**.
5. Click the collapsed stack icon on your dock to smoothly expand and collapse your items.
</details>

<details markdown="1">
<summary><strong>Does Plank Studio work with multiple monitors?</strong></summary>

Yes! You can:
- Assign specific docks to dedicated monitors under **Preferences → Position → Monitor**.
- Enable **"On Active Display"** to have the dock follow your mouse cursor to whichever monitor you are actively using.
- Move docks to your active monitor via a keyboard shortcut by triggering the USR1 signal:
  ```bash
  killall -USR1 plank
  ```
</details>

<details markdown="1">
<summary><strong>How do I auto-start Plank Studio on login?</strong></summary>

Add Plank Studio to your desktop environment's startup applications. The launch command is simply:
```bash
plank
```
All enabled docks will automatically launch together.
</details>

<details markdown="1">
<summary><strong>Can I run Plank Studio alongside the original Plank?</strong></summary>

No. Completely uninstall original Plank before installing Plank Studio to avoid conflicting libraries and D-Bus services.
</details>

<details markdown="1">
<summary><strong>Running indicators not showing after login?</strong></summary>

If the running indicator glow doesn't appear under active applications after logging in, `bamfdaemon` may not be running.

**Solution 1:** Add `bamfdaemon` to your desktop startup applications (typically `/usr/lib/x86_64-linux-gnu/bamf/bamfdaemon` or `/usr/lib/bamf/bamfdaemon`).

**Solution 2:** Fix the systemd user service with a drop-in override:
```bash
mkdir -p ~/.config/systemd/user/bamfdaemon.service.d/
echo -e "[Service]\nRestart=no" > ~/.config/systemd/user/bamfdaemon.service.d/override.conf
systemctl --user daemon-reload
```
</details>

<details markdown="1">
<summary><strong>Plank sensitivity extends too far in IceWM?</strong></summary>

If you use IceWM and clicking near the dock becomes unresponsive in adjacent windows, tell IceWM not to manage the dock window. Add this line to `~/.icewm/winoptions`:
```
plank.dock.doNotManage: 1
```
</details>

<details markdown="1">
<summary><strong>How can application developers show badges or progress bars on dock icons?</strong></summary>

Plank Studio supports the [Unity LauncherAPI specification](https://wiki.ubuntu.com/Unity/LauncherAPI), enabling applications to display notification counters, progress bars, and urgent state indicators directly on their dock icons.
</details>

---

## Third-Party Docklets

Plank Studio maintains 100% API compatibility with Plank docklets. Developers are encouraged to create custom docklets! See [DOCKLETS.md](DOCKLETS.md) for a comprehensive development guide.

Popular third-party docklets:
- [Last.fm](https://github.com/zquestz/lastfm-docklet) – Displays recent Last.fm scrobbles.
- [Picky](https://github.com/zquestz/picky) – Advanced color picker docklet.
- [Quit](https://github.com/androlekss/quit.git) – Quick access to session logout and power actions.
- [myIP](https://github.com/androlekss/ip-docklet.git) – Displays current public IP address.
- [Volmatic](https://github.com/androlekss/volmatic-docklet.git) – System volume controller docklet.

---

## Building API Documentation

To generate developer API documentation locally:

```bash
meson setup --prefix=/usr build
meson configure -D enable-docs=true build
meson compile -C build
meson compile -C build all-docs
```

The generated documentation will be available in `build/docs`.

---

## Getting Involved & Reporting Bugs

- **Report Issues**: Report bugs and submit feature requests on [GitHub Issues](https://github.com/zquestz/plank-reloaded/issues).
- **Contribute**: Pull requests and patches are always welcome. See [HACKING.md](HACKING.md) for developer guidelines.
- **Translations**: Help translate Plank Studio into your language on [Crowdin](https://crowdin.com/project/plank-reloaded).
