# SVTE - Simple VTE Terminal Emulator

A lightweight terminal emulator that just works. It runs on both Wayland and X11, supports tabs, and looks good with a dark Gruvbox color scheme.

## What is this?

SVTE is a simple terminal emulator built with GTK and VTE. If you're looking for a no-frills terminal that's easy to build and customize, this might be for you. It's about 470 lines of C code, so you can actually read and understand the whole thing.

## Features

The basics work well:
- Multiple tabs in one window
- Copy and paste with Ctrl+Shift+C/V
- 10,000 lines of scrollback
- Works on Wayland and X11
- Gruvbox dark theme (easy on the eyes)
- Sixel image support if you have VTE 0.62 or newer
- Pretty lightweight - uses about 30-40MB of RAM per window

## Getting Started

First, install the dependencies. Pick your distro:

**On Arch or Manjaro:**
```bash
sudo pacman -S gtk3 vte3
```

**On Ubuntu or Debian:**
```bash
sudo apt update
sudo apt install libgtk-3-dev libvte-2.91-dev
```

**On Fedora:**
```bash
sudo dnf install gtk3-devel vte291-devel
```

**On openSUSE:**
```bash
sudo zypper install gtk3-devel vte-devel
```

Then build it:
```bash
make
```

Try it out:
```bash
./svte
```

If you like it, install it:
```bash
sudo make install
```

Or just run the install script which does everything:
```bash
./install.sh
```

## Using It

Once it's running, here are the keyboard shortcuts you'll probably use:

**For copy/paste:**
- Ctrl+Shift+C - Copy
- Ctrl+Shift+V - Paste
- Middle mouse click also pastes (standard Linux behavior)

**For tabs:**
- Ctrl+Shift+T - New tab
- Click the **+** button in the tab bar - New tab
- Ctrl+Shift+W - Close current tab
- Ctrl+PageUp - Go to previous tab
- Ctrl+PageDown - Go to next tab
- Alt+1 through Alt+9 - Jump to a specific tab

## Making It Your Own

Want to change something? Just edit `svte.c` and rebuild. Here are some common tweaks:

**Different font:**

Find this line and change it:
```c
PangoFontDescription *font_desc = pango_font_description_from_string("Monospace 11");
```

Try "JetBrains Mono 12" or "Fira Code 11" or whatever you like.

**Bigger or smaller window:**

Change these numbers (width and height in pixels):
```c
gtk_window_set_default_size(GTK_WINDOW(app_data.window), 900, 600);
```

**More scrollback:**

Change this number (it's in lines):
```c
vte_terminal_set_scrollback_lines(terminal, 10000);
```

**Transparency:**

Add this line in the `configure_terminal` function:
```c
vte_terminal_set_background_alpha(terminal, 0.95);
```

The number is opacity from 0.0 (invisible) to 1.0 (solid).

**Different colors:**

The colors are in the `init_gruvbox_colors()` function. The numbers are RGB values from 0.0 to 1.0. For example, if you want a Solarized Dark theme instead:

```c
colors->fg = (GdkRGBA){0.51, 0.58, 0.59, 1.0};  // text color
colors->bg = (GdkRGBA){0.00, 0.17, 0.21, 1.0};  // background
```

After you make changes:
```bash
make clean
make
```

## Why VTE?

VTE is the terminal widget library that GNOME Terminal uses. It handles all the complicated terminal stuff - escape codes, PTY management, Unicode, etc. This means SVTE can be simple while still being fully functional. Writing all that from scratch would be thousands of lines of code and probably buggy.

## Testing

Want to see if everything works?
```bash
./svte --test
```

Or:
```bash
make test
```

This runs a self-test that checks if your GTK and VTE versions are good, if colors work, and so on.

## Command Line Options

```bash
svte --help       # Shows help
svte --version    # Shows version
svte --test       # Runs self-test
```

## What You Need

- GTK 3.0 or newer
- VTE 2.91 or newer (0.62+ recommended for Sixel graphics)
- GLib 2.0
- Pango for fonts
- A C compiler (gcc works fine)

## Troubleshooting

**"Package gtk+-3.0 not found" when building:**

You need the development packages, not just the regular ones. On Ubuntu/Debian, that's `libgtk-3-dev` and `libvte-2.91-dev`. On Fedora, it's `gtk3-devel` and `vte291-devel`.

**Terminal won't start on Wayland:**

Try forcing X11 mode:
```bash
GDK_BACKEND=x11 ./svte
```

If that works, there might be a Wayland-specific issue. File a bug report if you find one.

**Sixel images don't show up:**

Check your VTE version:
```bash
pkg-config --modversion vte-2.91
```

You need at least 0.62 for Sixel support. If yours is older, you can still use the terminal, just no inline images.

## Uninstalling

If you installed it and want to remove it:
```bash
./uninstall.sh
```

Or manually:
```bash
sudo make uninstall
```

## Ideas for Improvements

If you want to hack on this, here are some ideas:

- Add a config file so you don't have to recompile to change settings
- Add more color schemes
- Add URL detection and clicking
- Add a search feature
- Add split panes (horizontal/vertical)
- Add custom keybindings
- Add a font picker in the UI

## Similar Projects

If SVTE doesn't fit your needs, check out:

- **Alacritty** - GPU-accelerated, very fast, written in Rust
- **st** - The Suckless terminal, super minimal
- **foot** - Fast Wayland-native terminal
- **GNOME Terminal** - Full-featured, also uses VTE
- **Kitty** - Lots of features, GPU-accelerated

## The Code

The whole thing is about 470 lines of C. It's split into:
- Terminal configuration and color setup
- Tab management
- Keyboard shortcuts
- VTE integration
- A test suite

If you're learning C or GTK programming, this might be a good project to study. It's small enough to understand but does real work.

## Contributing

Found a bug? Want to add a feature? Pull requests are welcome. This is a simple project, so let's keep it that way - no adding a GUI toolkit just to configure fonts or anything like that.

## License

Do whatever you want with this code. It's basically a minimal example of how to use VTE, so use it, learn from it, fork it, whatever.

## Credits

Built with VTE (the GNOME terminal widget library) and uses the Gruvbox color scheme. Inspired by all the minimal terminal emulators out there that prove you don't need 50,000 lines of code to have a working terminal.

---

That's it. Build it, use it, hack on it. Enjoy your new terminal.
