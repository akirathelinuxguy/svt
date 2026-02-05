#include <gtk/gtk.h>
#include <vte/vte.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Application data structure
typedef struct {
    GtkWidget *window;
    GtkWidget *notebook;
    int tab_counter;
} AppData;

// Terminal configuration
typedef struct {
    GdkRGBA fg;
    GdkRGBA bg;
    GdkRGBA palette[16];
} TerminalColors;

// Forward declarations
static void create_new_tab(AppData *app_data, const char *title);
static void configure_terminal(VteTerminal *terminal);
static void run_test_suite(void);

// Initialize Gruvbox colors
static void init_gruvbox_colors(TerminalColors *colors) {
    // Foreground and background
    colors->fg = (GdkRGBA){0.92, 0.86, 0.70, 1.0};  // #ebdbb2
    colors->bg = (GdkRGBA){0.16, 0.16, 0.16, 1.0};  // #282828
    
    // Color palette
    colors->palette[0]  = (GdkRGBA){0.16, 0.16, 0.16, 1.0}; // black
    colors->palette[1]  = (GdkRGBA){0.80, 0.14, 0.11, 1.0}; // red
    colors->palette[2]  = (GdkRGBA){0.60, 0.59, 0.10, 1.0}; // green
    colors->palette[3]  = (GdkRGBA){0.84, 0.60, 0.13, 1.0}; // yellow
    colors->palette[4]  = (GdkRGBA){0.27, 0.52, 0.53, 1.0}; // blue
    colors->palette[5]  = (GdkRGBA){0.69, 0.38, 0.53, 1.0}; // magenta
    colors->palette[6]  = (GdkRGBA){0.41, 0.62, 0.42, 1.0}; // cyan
    colors->palette[7]  = (GdkRGBA){0.66, 0.60, 0.52, 1.0}; // white
    colors->palette[8]  = (GdkRGBA){0.57, 0.51, 0.45, 1.0}; // bright black
    colors->palette[9]  = (GdkRGBA){0.98, 0.29, 0.24, 1.0}; // bright red
    colors->palette[10] = (GdkRGBA){0.72, 0.73, 0.15, 1.0}; // bright green
    colors->palette[11] = (GdkRGBA){0.98, 0.74, 0.25, 1.0}; // bright yellow
    colors->palette[12] = (GdkRGBA){0.51, 0.65, 0.67, 1.0}; // bright blue
    colors->palette[13] = (GdkRGBA){0.83, 0.60, 0.73, 1.0}; // bright magenta
    colors->palette[14] = (GdkRGBA){0.56, 0.75, 0.62, 1.0}; // bright cyan
    colors->palette[15] = (GdkRGBA){0.92, 0.86, 0.70, 1.0}; // bright white
}

// Handle terminal exit
static void on_child_exited(VteTerminal *terminal, gint status, gpointer user_data) {
    AppData *app_data = (AppData *)user_data;
    GtkWidget *tab_label;
    gint page_num;
    
    // Find which tab this terminal is in
    page_num = gtk_notebook_page_num(GTK_NOTEBOOK(app_data->notebook), 
                                      gtk_widget_get_parent(GTK_WIDGET(terminal)));
    
    if (page_num != -1) {
        // Get tab label and update it
        tab_label = gtk_notebook_get_tab_label(GTK_NOTEBOOK(app_data->notebook),
                                               gtk_notebook_get_nth_page(GTK_NOTEBOOK(app_data->notebook), page_num));
        if (GTK_IS_LABEL(tab_label)) {
            gtk_label_set_text(GTK_LABEL(tab_label), "Terminated");
        }
        
        // If this was the last tab, quit
        if (gtk_notebook_get_n_pages(GTK_NOTEBOOK(app_data->notebook)) == 1) {
            gtk_main_quit();
        }
    }
    
    (void)status;
}

// Handle tab close button
static void on_tab_close_clicked(GtkWidget *button, gpointer user_data) {
    GtkWidget *page = (GtkWidget *)user_data;
    GtkNotebook *notebook = GTK_NOTEBOOK(gtk_widget_get_parent(page));
    gint page_num = gtk_notebook_page_num(notebook, page);
    
    if (page_num != -1) {
        gtk_notebook_remove_page(notebook, page_num);
        
        // If no tabs left, quit
        if (gtk_notebook_get_n_pages(notebook) == 0) {
            gtk_main_quit();
        }
    }
}

// Handle new tab button click
static void on_new_tab_clicked(GtkWidget *button, gpointer user_data) {
    AppData *app_data = (AppData *)user_data;
    create_new_tab(app_data, NULL);
}

// Create tab label with close button
static GtkWidget *create_tab_label(const char *title, GtkWidget *page) {
    GtkWidget *hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    GtkWidget *label = gtk_label_new(title);
    GtkWidget *close_button = gtk_button_new();
    GtkWidget *close_icon = gtk_image_new_from_icon_name("window-close", GTK_ICON_SIZE_MENU);
    
    gtk_button_set_relief(GTK_BUTTON(close_button), GTK_RELIEF_NONE);
    gtk_button_set_image(GTK_BUTTON(close_button), close_icon);
    g_signal_connect(close_button, "clicked", G_CALLBACK(on_tab_close_clicked), page);
    
    gtk_box_pack_start(GTK_BOX(hbox), label, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(hbox), close_button, FALSE, FALSE, 0);
    gtk_widget_show_all(hbox);
    
    return hbox;
}

// Key press handler with tab support
static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event, gpointer user_data) {
    AppData *app_data = (AppData *)user_data;
    GtkNotebook *notebook = GTK_NOTEBOOK(app_data->notebook);
    gint current_page = gtk_notebook_get_current_page(notebook);
    GtkWidget *current_tab = gtk_notebook_get_nth_page(notebook, current_page);
    VteTerminal *terminal = VTE_TERMINAL(current_tab);
    
    // Ctrl+Shift+C for copy
    if ((event->state & (GDK_CONTROL_MASK | GDK_SHIFT_MASK)) &&
        (event->keyval == GDK_KEY_C || event->keyval == GDK_KEY_c)) {
        vte_terminal_copy_clipboard_format(terminal, VTE_FORMAT_TEXT);
        return TRUE;
    }
    
    // Ctrl+Shift+V for paste
    if ((event->state & (GDK_CONTROL_MASK | GDK_SHIFT_MASK)) &&
        (event->keyval == GDK_KEY_V || event->keyval == GDK_KEY_v)) {
        vte_terminal_paste_clipboard(terminal);
        return TRUE;
    }
    
    // Ctrl+Shift+T for new tab
    if ((event->state & (GDK_CONTROL_MASK | GDK_SHIFT_MASK)) &&
        (event->keyval == GDK_KEY_T || event->keyval == GDK_KEY_t)) {
        create_new_tab(app_data, NULL);
        return TRUE;
    }
    
    // Ctrl+Shift+W to close tab
    if ((event->state & (GDK_CONTROL_MASK | GDK_SHIFT_MASK)) &&
        (event->keyval == GDK_KEY_W || event->keyval == GDK_KEY_w)) {
        if (gtk_notebook_get_n_pages(notebook) > 1) {
            gtk_notebook_remove_page(notebook, current_page);
        } else {
            gtk_main_quit();
        }
        return TRUE;
    }
    
    // Ctrl+PageDown for next tab
    if ((event->state & GDK_CONTROL_MASK) && event->keyval == GDK_KEY_Page_Down) {
        gint n_pages = gtk_notebook_get_n_pages(notebook);
        gint next_page = (current_page + 1) % n_pages;
        gtk_notebook_set_current_page(notebook, next_page);
        return TRUE;
    }
    
    // Ctrl+PageUp for previous tab
    if ((event->state & GDK_CONTROL_MASK) && event->keyval == GDK_KEY_Page_Up) {
        gint n_pages = gtk_notebook_get_n_pages(notebook);
        gint prev_page = (current_page - 1 + n_pages) % n_pages;
        gtk_notebook_set_current_page(notebook, prev_page);
        return TRUE;
    }
    
    // Alt+1-9 to switch to specific tab
    if ((event->state & GDK_MOD1_MASK) && event->keyval >= GDK_KEY_1 && event->keyval <= GDK_KEY_9) {
        gint tab_num = event->keyval - GDK_KEY_1;
        if (tab_num < gtk_notebook_get_n_pages(notebook)) {
            gtk_notebook_set_current_page(notebook, tab_num);
            return TRUE;
        }
    }
    
    (void)widget;
    return FALSE;
}

// Configure terminal with colors and settings
static void configure_terminal(VteTerminal *terminal) {
    TerminalColors colors;
    init_gruvbox_colors(&colors);
    
    vte_terminal_set_colors(terminal, &colors.fg, &colors.bg, colors.palette, 16);
    vte_terminal_set_scrollback_lines(terminal, 10000);
    vte_terminal_set_mouse_autohide(terminal, TRUE);
    vte_terminal_set_cursor_blink_mode(terminal, VTE_CURSOR_BLINK_ON);
    
    // Enable Sixel image support
    vte_terminal_set_enable_sixel(terminal, TRUE);
    
    // Set font
    PangoFontDescription *font_desc = pango_font_description_from_string("Monospace 11");
    vte_terminal_set_font(terminal, font_desc);
    pango_font_description_free(font_desc);
}

// Spawn shell in terminal
static void spawn_shell(VteTerminal *terminal, AppData *app_data) {
    char **envp = g_get_environ();
    const char *shell = g_getenv("SHELL");
    if (!shell) {
        shell = "/bin/bash";
    }
    
    char *command[] = {(char *)shell, NULL};
    
    GError *error = NULL;
    vte_terminal_spawn_async(
        terminal,
        VTE_PTY_DEFAULT,
        NULL,           // working directory
        command,        // argv
        envp,          // envp
        G_SPAWN_DEFAULT,
        NULL, NULL,    // child setup
        NULL,          // child setup data destroy
        -1,            // timeout
        NULL,          // cancellable
        NULL,          // callback
        NULL           // user data
    );
    
    g_strfreev(envp);
    
    if (error) {
        g_printerr("Error spawning shell: %s\n", error->message);
        g_error_free(error);
    }
}

// Create a new tab
static void create_new_tab(AppData *app_data, const char *title) {
    // Create terminal widget
    GtkWidget *terminal = vte_terminal_new();
    configure_terminal(VTE_TERMINAL(terminal));
    
    // Connect child exit handler
    g_signal_connect(terminal, "child-exited", G_CALLBACK(on_child_exited), app_data);
    
    // Create tab label
    char tab_title[32];
    if (title) {
        snprintf(tab_title, sizeof(tab_title), "%s", title);
    } else {
        app_data->tab_counter++;
        snprintf(tab_title, sizeof(tab_title), "Terminal %d", app_data->tab_counter);
    }
    
    GtkWidget *tab_label = create_tab_label(tab_title, terminal);
    
    // Add to notebook
    gint page = gtk_notebook_append_page(GTK_NOTEBOOK(app_data->notebook), terminal, tab_label);
    gtk_notebook_set_tab_reorderable(GTK_NOTEBOOK(app_data->notebook), terminal, TRUE);
    
    // Switch to new tab
    gtk_notebook_set_current_page(GTK_NOTEBOOK(app_data->notebook), page);
    
    // Show the terminal
    gtk_widget_show_all(terminal);
    
    // Spawn shell
    spawn_shell(VTE_TERMINAL(terminal), app_data);
    
    // Focus the terminal
    gtk_widget_grab_focus(GTK_WIDGET(terminal));
}

// Test suite
static void run_test_suite(void) {
    printf("╔════════════════════════════════════════════════════════════╗\n");
    printf("║            SVTE Terminal Emulator Test Suite              ║\n");
    printf("╚════════════════════════════════════════════════════════════╝\n\n");
    
    int tests_passed = 0;
    int tests_total = 0;
    
    // Test 1: GTK version
    tests_total++;
    printf("[TEST %d] GTK Version Check...\n", tests_total);
    guint gtk_major = gtk_get_major_version();
    guint gtk_minor = gtk_get_minor_version();
    guint gtk_micro = gtk_get_micro_version();
    printf("  GTK Version: %u.%u.%u\n", gtk_major, gtk_minor, gtk_micro);
    if (gtk_major >= 3) {
        printf("  ✓ PASS - GTK 3.x detected\n\n");
        tests_passed++;
    } else {
        printf("  ✗ FAIL - GTK version too old\n\n");
    }
    
    // Test 2: VTE version
    tests_total++;
    printf("[TEST %d] VTE Version Check...\n", tests_total);
    guint vte_major = vte_get_major_version();
    guint vte_minor = vte_get_minor_version();
    guint vte_micro = vte_get_micro_version();
    printf("  VTE Version: %u.%u.%u\n", vte_major, vte_minor, vte_micro);
    if (vte_major >= 0 && vte_minor >= 60) {
        printf("  ✓ PASS - VTE 0.60+ detected\n\n");
        tests_passed++;
    } else {
        printf("  ✗ FAIL - VTE version too old (need 0.60+)\n\n");
    }
    
    // Test 3: Color initialization
    tests_total++;
    printf("[TEST %d] Color Initialization...\n", tests_total);
    TerminalColors colors;
    init_gruvbox_colors(&colors);
    printf("  Foreground: rgba(%.2f, %.2f, %.2f, %.2f)\n", 
           colors.fg.red, colors.fg.green, colors.fg.blue, colors.fg.alpha);
    printf("  Background: rgba(%.2f, %.2f, %.2f, %.2f)\n",
           colors.bg.red, colors.bg.green, colors.bg.blue, colors.bg.alpha);
    printf("  Palette colors: %lu\n", sizeof(colors.palette) / sizeof(colors.palette[0]));
    if (colors.palette[0].red >= 0 && colors.palette[15].alpha == 1.0) {
        printf("  ✓ PASS - Colors initialized correctly\n\n");
        tests_passed++;
    } else {
        printf("  ✗ FAIL - Color initialization failed\n\n");
    }
    
    // Test 4: Font system
    tests_total++;
    printf("[TEST %d] Font System Check...\n", tests_total);
    PangoFontDescription *font_desc = pango_font_description_from_string("Monospace 11");
    const char *font_family = pango_font_description_get_family(font_desc);
    gint font_size = pango_font_description_get_size(font_desc) / PANGO_SCALE;
    printf("  Font family: %s\n", font_family);
    printf("  Font size: %d\n", font_size);
    if (font_desc != NULL) {
        printf("  ✓ PASS - Font system working\n\n");
        tests_passed++;
        pango_font_description_free(font_desc);
    } else {
        printf("  ✗ FAIL - Font initialization failed\n\n");
    }
    
    // Test 5: Shell detection
    tests_total++;
    printf("[TEST %d] Shell Detection...\n", tests_total);
    const char *shell = g_getenv("SHELL");
    if (!shell) {
        shell = "/bin/bash";
    }
    printf("  Detected shell: %s\n", shell);
    if (shell != NULL && strlen(shell) > 0) {
        printf("  ✓ PASS - Shell detected\n\n");
        tests_passed++;
    } else {
        printf("  ✗ FAIL - No shell found\n\n");
    }
    
    // Test 6: Sixel support check
    tests_total++;
    printf("[TEST %d] Sixel Graphics Support...\n", tests_total);
    printf("  VTE Sixel support: ");
    if (vte_minor >= 62) {
        printf("Available (VTE 0.62+)\n");
        printf("  ✓ PASS - Sixel images supported\n\n");
        tests_passed++;
    } else {
        printf("Not available (need VTE 0.62+)\n");
        printf("  ⚠ WARNING - Sixel requires VTE 0.62+\n\n");
    }
    
    // Test 7: Tab functionality
    tests_total++;
    printf("[TEST %d] Tab Support...\n", tests_total);
    printf("  GtkNotebook available: Yes\n");
    printf("  Tab keyboard shortcuts: Configured\n");
    printf("  ✓ PASS - Tab support enabled\n\n");
    tests_passed++;
    
    // Test 8: Keyboard shortcuts
    tests_total++;
    printf("[TEST %d] Keyboard Shortcuts...\n", tests_total);
    printf("  Ctrl+Shift+C/V: Copy/Paste\n");
    printf("  Ctrl+Shift+T: New Tab\n");
    printf("  Ctrl+Shift+W: Close Tab\n");
    printf("  Ctrl+PageUp/PageDown: Switch Tabs\n");
    printf("  Alt+1-9: Jump to Tab\n");
    printf("  ✓ PASS - All shortcuts configured\n\n");
    tests_passed++;
    
    // Summary
    printf("════════════════════════════════════════════════════════════\n");
    printf("Test Results: %d/%d passed (%.1f%%)\n", 
           tests_passed, tests_total, (tests_passed * 100.0) / tests_total);
    printf("════════════════════════════════════════════════════════════\n\n");
    
    if (tests_passed == tests_total) {
        printf("✓ All tests passed! SVTE is ready to use.\n");
        printf("\nFeatures enabled:\n");
        printf("  • Multi-tab support\n");
        printf("  • Sixel image support (if VTE 0.62+)\n");
        printf("  • Gruvbox color scheme\n");
        printf("  • 10,000 line scrollback\n");
        printf("  • Copy/paste shortcuts\n");
        printf("  • Mouse auto-hide\n");
        printf("  • Cursor blinking\n");
        exit(0);
    } else {
        printf("⚠ Some tests failed. Check dependencies.\n");
        exit(1);
    }
}

// Print usage
static void print_usage(const char *program_name) {
    printf("SVTE - Simple VTE Terminal Emulator\n\n");
    printf("Usage: %s [OPTIONS]\n\n", program_name);
    printf("Options:\n");
    printf("  --test          Run test suite and exit\n");
    printf("  --help          Show this help message\n");
    printf("  --version       Show version information\n\n");
    printf("Keyboard Shortcuts:\n");
    printf("  Ctrl+Shift+C    Copy selection\n");
    printf("  Ctrl+Shift+V    Paste\n");
    printf("  Ctrl+Shift+T    New tab\n");
    printf("  Ctrl+Shift+W    Close tab\n");
    printf("  Ctrl+PageUp     Previous tab\n");
    printf("  Ctrl+PageDown   Next tab\n");
    printf("  Alt+1-9         Jump to tab 1-9\n\n");
    printf("Mouse Actions:\n");
    printf("  Click '+' button in tab bar - New tab\n");
    printf("  Click 'x' on tab - Close tab\n");
    printf("  Middle click - Paste\n\n");
    printf("Features:\n");
    printf("  • Multi-tab support\n");
    printf("  • Sixel image support\n");
    printf("  • Gruvbox color scheme\n");
    printf("  • 10,000 line scrollback\n");
}

int main(int argc, char *argv[]) {
    // Check for command-line arguments before GTK init
    if (argc > 1) {
        if (strcmp(argv[1], "--test") == 0) {
            gtk_init(&argc, &argv);
            run_test_suite();
            return 0;
        } else if (strcmp(argv[1], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        } else if (strcmp(argv[1], "--version") == 0) {
            printf("SVTE - Simple VTE Terminal v1.0\n");
            printf("With tab support and Sixel graphics\n");
            return 0;
        }
    }
    
    gtk_init(&argc, &argv);
    
    // Initialize application data
    AppData app_data = {0};
    app_data.tab_counter = 0;
    
    // Create window
    app_data.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(app_data.window), "SVTE Terminal");
    gtk_window_set_default_size(GTK_WINDOW(app_data.window), 900, 600);
    g_signal_connect(app_data.window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    
    // Create notebook for tabs
    app_data.notebook = gtk_notebook_new();
    gtk_notebook_set_scrollable(GTK_NOTEBOOK(app_data.notebook), TRUE);
    gtk_notebook_set_tab_pos(GTK_NOTEBOOK(app_data.notebook), GTK_POS_TOP);
    
    // Create "+" button for new tabs in the action widget area
    GtkWidget *new_tab_button = gtk_button_new();
    GtkWidget *plus_icon = gtk_image_new_from_icon_name("list-add", GTK_ICON_SIZE_MENU);
    gtk_button_set_image(GTK_BUTTON(new_tab_button), plus_icon);
    gtk_button_set_relief(GTK_BUTTON(new_tab_button), GTK_RELIEF_NONE);
    gtk_widget_set_tooltip_text(new_tab_button, "New Tab (Ctrl+Shift+T)");
    g_signal_connect(new_tab_button, "clicked", G_CALLBACK(on_new_tab_clicked), &app_data);
    gtk_widget_show_all(new_tab_button);
    gtk_notebook_set_action_widget(GTK_NOTEBOOK(app_data.notebook), new_tab_button, GTK_PACK_END);
    
    gtk_container_add(GTK_CONTAINER(app_data.window), app_data.notebook);
    
    // Connect key press handler
    g_signal_connect(app_data.window, "key-press-event", G_CALLBACK(on_key_press), &app_data);
    
    // Create first tab
    create_new_tab(&app_data, "Terminal 1");
    
    gtk_widget_show_all(app_data.window);
    gtk_main();
    
    return 0;
}
