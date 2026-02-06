# SVTE Wiki: Configuration & Customization

Welcome to the comprehensive configuration guide for SVTE (Simple VTE). Because SVTE is designed to be lightweight and minimal, it currently uses a "compile-time configuration" model. This means you customize the terminal by editing the source code directly and then rebuilding the binary.

## 1. Where to Configure

All user settings are stored within the main function of the svte.c file. Look for the AppData app = {0}; initialization and the block of code immediately following it that starts with app.config.
## 2. Configuration Options & Syntax
Visuals and Window Behavior

You can adjust the initial footprint and the font rendering of your terminal using these variables:
Variable	Type	Description
app.config.window_width	int	The starting width of the window in pixels (default: 1000).
app.config.window_height	int	The starting height of the window in pixels (default: 700).
app.config.font_name	string	The Pango font family (e.g., "Source Code Pro", "Monospace").
app.config.font_size	int	The font size as a standard integer.
Color Schemes (Themes)

SVTE includes a built-in theme engine. To change your theme, modify the color_scheme string:

    Gruvbox: strcpy(app.config.color_scheme, "gruvbox");

    Solarized Dark: strcpy(app.config.color_scheme, "solarized-dark");

    Note: Theme colors are defined in the apply_theme function. If you are comfortable with C, you can add your own hex codes to the TerminalColors struct there.

# Keybindings (Keyboard Shortcuts)

SVTE uses GTK Accelerator Strings. These strings are case-sensitive and must be wrapped in < > for modifiers.

    Modifiers: <Control>, <Shift>, <Alt>

    Syntax Example: "<Control><Shift>t"

Available Keybind Variables:

    New Tab: key_new_tab

    Close Tab: key_close_tab

    Navigation: key_next_tab and key_prev_tab

    Clipboard: key_copy and key_paste

# 3. Applying Your Changes

After you save your edits in svte.c, you must recompile the program for the changes to take effect. Run the following command in your terminal:
Bash

gcc `pkg-config --cflags gtk+-3.0 vte-2.91` -o svte svte.c `pkg-config --libs gtk+-3.0 vte-2.91`

# 4. Community Discussions: Posting Your Config

We love seeing how you’ve customized your terminal! When sharing your setup on our Discussions page, please follow these guidelines:
Format

Use a C code block to share your specific app.config values. This makes it easy for others to copy and paste into their own svte.c.
Example Post Structure

Title: [Theme] Pastel Night by User123 Content:

    I wanted something softer on the eyes. Here are my settings:
    C

    app.config.font_size = 13;
    strcpy(app.config.font_name, "JetBrains Mono");
    strcpy(app.config.color_scheme, "solarized-dark");
    strcpy(app.config.key_new_tab, "<Alt>t");

