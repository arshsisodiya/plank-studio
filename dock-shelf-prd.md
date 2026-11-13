# Feature PRD: Dock Shelf -- Temporary File & Folder Storage

## 1. Overview

Implement a new feature called **Shelf** that allows users to
temporarily collect, organize, and access files and folders directly
from the dock.

The Shelf should behave like a compact file manager integrated into the
dock. Users should be able to drag and drop files or folders into it,
browse their contents, navigate through nested directories, and quickly
open files without needing to open the full file manager.

The feature should be inspired by the Shelf functionality demonstrated
in the provided reference images.

The Shelf must be available as an independent item that users can add to
any dock.

## 2. Core Functionality

### 2.1 Add Shelf to Dock

-   Introduce a new dock item called **Shelf**.
-   Users should be able to add or remove the Shelf from any dock.
-   Display a recognizable Shelf icon in the dock.
-   Show a tooltip labelled "Shelf" on hover.
-   Each dock should be able to have its own Shelf instance.
-   The Shelf icon should follow the existing dock icon sizing, hover
    effects, zoom animations, and visual styling.

### 2.2 Drag and Drop Files & Folders

Users must be able to drag and drop files and folders directly onto the
Shelf icon.

Expected behaviour:

1.  When a user drags a file or folder over the Shelf icon, provide a
    visual indication that the Shelf is ready to accept the item.
2.  When the user drops the item, add it to the Shelf.
3.  Support multiple files and folders being added simultaneously.
4.  Display the added items inside the Shelf panel.
5.  Allow users to drag additional items into the Shelf while it is
    already open.
6.  Support drag-and-drop from the system file manager and other
    compatible applications.

**Important:** Adding an item to the Shelf must not physically move,
copy, rename, or modify the original file. The Shelf should maintain
references to the original file and folder locations.

### 2.3 Shelf Popup Interface

Clicking the Shelf icon should open a floating panel near the dock.

The panel should:

-   Appear adjacent to the Shelf icon.
-   Automatically position itself according to the dock's screen edge.
-   Adapt to left, right, top, and bottom dock positions.
-   Have a modern, minimal, translucent interface.
-   Include a header displaying the Shelf name and total item count.
-   Display files and folders in a clean grid or list layout.
-   Provide a clear empty state when no items have been added.

The panel should open and close with smooth animations.

### 2.4 Folder Navigation and Browsing

This is one of the most important parts of the feature.

When a user adds a folder to the Shelf, they should be able to browse
its contents directly inside the Shelf panel.

Expected behaviour:

-   Clicking a folder opens its contents inside the Shelf.
-   Display all files and subfolders contained within it.
-   Clicking a subfolder navigates further into that directory.
-   Users can navigate through multiple levels of nested folders.
-   Provide breadcrumb navigation to indicate the current directory.
-   Include a back navigation option to return to the previous
    directory.
-   Clicking a file should open it using the system's default
    application.
-   Users should be able to navigate back to the Shelf's root collection
    at any time.

For example:

`Shelf → Documents → Projects → MagnutAI → Design → logo.png`

Users should be able to navigate this entire folder hierarchy without
opening another file manager window.

### 2.5 File Interaction

Support the following interactions:

-   Single-click a file to open it using its default application.
-   Double-click folders to navigate into them, if consistent with the
    chosen interaction design.
-   Right-click files or folders to display a context menu.
-   Remove individual items from the Shelf.
-   Drag items out of the Shelf into another folder or compatible
    application.
-   Display appropriate file icons and folder thumbnails.
-   Show file names and relevant metadata where useful.

Suggested context menu actions:

**For files:** - Open - Open With - Open Containing Folder - Copy -
Remove from Shelf

**For folders:** - Open - Open in File Manager - Copy - Remove from
Shelf

Removing an item from the Shelf must never delete the original file or
folder.

### 2.6 Shelf Management

Provide basic management functionality:

-   Add files and folders.
-   Remove individual items.
-   Clear All to remove every item from the Shelf.
-   Display the total number of stored items.
-   Handle missing or deleted original files gracefully.
-   Preserve the Shelf contents after application restarts.

If an original file is moved or deleted outside the Shelf, detect the
unavailable reference and display an appropriate missing-item state
instead of crashing.

## 3. User Experience & Visual Design

Follow the visual direction of the provided screenshots.

### Design characteristics

-   Translucent glass-like panel.
-   Subtle background blur where supported.
-   Rounded corners.
-   Thin, subtle borders.
-   Clean typography.
-   Consistent spacing and alignment.
-   Minimal header with Shelf icon, title, and item count.
-   Smooth opening and closing animations.
-   Subtle hover states for files and folders.
-   Clear folder and file icons.

### Panel layout

**Header:** - Shelf icon. - Shelf title. - Current item count. -
Optional settings or menu button.

**Navigation:** - Back button. - Breadcrumb path. - Current folder name.

**Content:** - Grid or list of files and folders. - Appropriate icons or
thumbnails. - File and folder names. - Empty state when there is no
content.

**Footer:** - Clear All action. - Optional item management controls.

Keep the interface compact and avoid unnecessary visual elements.

## 4. Dock Position Adaptation

The Shelf panel must intelligently adapt to the dock's position.

-   Bottom dock: Open the panel upwards.
-   Top dock: Open the panel downwards.
-   Left dock: Open the panel towards the right.
-   Right dock: Open the panel towards the left.

Ensure the panel remains within the available screen boundaries and does
not overlap important desktop areas unnecessarily.

## 5. Persistence & Storage

The Shelf should maintain its contents across application restarts.

Store references to files and folders rather than duplicating their
contents.

Persist: - Original file/folder paths or appropriate file URIs. - Item
type. - Display metadata where necessary. - Shelf configuration. - Item
ordering.

If multiple docks are supported, maintain independent Shelf
configurations for each dock.

Use a reliable storage mechanism compatible with the existing
application architecture.

Handle permission errors, unavailable mount points, broken paths, and
inaccessible directories gracefully.

## 6. Technical & Implementation Requirements

-   Integrate with the existing dock architecture.
-   Use the native operating system's file handling capabilities.
-   Support standard Linux file URIs and paths.
-   Implement proper filesystem access and directory enumeration.
-   Use native file-opening mechanisms to launch files with their
    default applications.
-   Support drag-and-drop events from external file managers.
-   Ensure drag-and-drop works with multiple selections.
-   Avoid blocking the dock's main UI thread during filesystem
    operations.
-   Handle large directories and unsupported file types gracefully.
-   Prevent duplicate references where appropriate.
-   Ensure all filesystem operations respect existing permissions.

Do not implement a separate, disconnected file manager. The Shelf must
be a native part of the dock experience.

## 7. Edge Cases

Handle the following scenarios:

-   Empty Shelf.
-   Empty folders.
-   Very large folders.
-   Deeply nested directories.
-   Files with long names.
-   Hidden files and folders.
-   Unsupported file types.
-   Files deleted after being added.
-   Files moved to another location.
-   Disconnected external drives.
-   Permission-restricted directories.
-   Duplicate items.
-   Multiple files dropped simultaneously.
-   Rapid opening and closing of the Shelf.
-   Multiple monitors and different screen resolutions.

## 8. Acceptance Criteria

The feature is considered complete when:

1.  Users can add Shelf to any dock.
2.  Users can drag and drop files and folders onto the Shelf.
3.  Multiple items can be added simultaneously.
4.  Clicking the Shelf opens a properly positioned floating panel.
5.  Added folders can be browsed inside the Shelf.
6.  Nested folders can be opened and navigated recursively.
7.  Files can be opened using their default applications.
8.  Users can remove individual items without deleting originals.
9.  Clear All works correctly.
10. Shelf contents persist after restarting the dock.
11. The panel adapts to all four dock positions.
12. Dragging items out of the Shelf works where supported.
13. Missing files and permission errors are handled gracefully.
14. Existing dock functionality remains unaffected.

## 9. Implementation Approach

Implement this as a complete, production-ready feature rather than a
visual prototype.

Before implementation:

1.  Inspect the existing dock architecture and understand how dock
    items, popup panels, file handling, and drag-and-drop currently
    work.
2.  Identify reusable components and existing filesystem integrations.
3.  Plan the Shelf's storage and navigation architecture.
4.  Implement the feature using the existing technology stack and design
    conventions.
5.  Test all interactions, including nested folder navigation and
    external drag-and-drop.

Avoid unnecessary architectural changes or unrelated modifications.

**Final Goal:** A lightweight, visually polished, temporary file and
folder storage system built directly into the dock, allowing users to
collect files, browse entire folder hierarchies, and access their
content without leaving the desktop environment.

------------------------------------------------------------------------

## Additional UX Recommendations

### 1. Breadcrumb Navigation

Show a path such as `Shelf / Projects / MagnutAI / Assets` so users can
understand their current location and navigate backwards easily.

### 2. Grid and List Views

Allow switching between icon grid and compact list views. This is
especially useful when a folder contains many files.

### 3. Drag Files Back Out

Allow dragging files from the Shelf directly onto the desktop, another
folder, or a compatible application. This makes the Shelf useful as a
genuine temporary workspace.

## Important Architectural Decision

Keep the Shelf non-destructive. It should reference original files
rather than move them into an internal storage directory. This makes it
a temporary collection space, not another file manager or storage
location.
