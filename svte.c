#include <gtk/gtk.h>
#include <vte/vte.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* --- Data Structures --- */

typedef struct {
    int window_width;
    int window_height;
    char font_name[64];
    int font_size;
    int scrollback_lines;
    char color_scheme[32];
    // Keybind strings from config
    char key_new_tab[32];
    char key_close_tab[32];
    char key_next_tab[32];
    char key_prev_tab[32];
    char key_copy[32];
    char key_paste[32];
} Config;

typedef struct {
    GtkWidget *window;
    GtkWidget *notebook;
    Config config;
    int tab_counter;
} AppData;

typedef struct {
    GdkRGBA fg;
    GdkRGBA bg;
    GdkRGBA palette[16];
} TerminalColors;

/* --- Themes --- */

static void apply_theme(VteTerminal *vte, const char *scheme) {
    TerminalColors colors;
    const char *p[16];

    if (strcmp(scheme, "solarized-dark") == 0) {
        gdk_rgba_parse(&colors.bg, "#002b36");
        gdk_rgba_parse(&colors.fg, "#839496");
        const char *s_p[] = {"#073642", "#dc322f", "#859900", "#b58900", "#268bd2", "#d33682", "#2aa198", "#eee8d5",
                             "#002b36", "#cb4b16", "#586e75", "#657b83", "#839496", "#6c71c4", "#93a1a1", "#fdf6e3"};
        memcpy(p, s_p, sizeof(p));
    } else { // Gruvbox Default
        gdk_rgba_parse(&colors.bg, "#282828");
        gdk_rgba_parse(&colors.fg, "#ebdbb2");
        const char *g_p[] = {"#282828", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#a89984",
                             "#928374", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", "#ebdbb2"};
        memcpy(p, g_p, sizeof(p));
    }

    for (int i = 0; i < 16; i++) gdk_rgba_parse(&colors.palette[i], p[i]);
    vte_terminal_set_colors(vte, &colors.fg, &colors.bg, colors.palette, 16);
}

/* --- Logic --- */

static void on_child_exited(VteTerminal *vte, gint status, gpointer user_data) {
    AppData *app = (AppData *)user_data;
    gtk_widget_destroy(GTK_WIDGET(vte));
    if (gtk_notebook_get_n_pages(GTK_NOTEBOOK(app->notebook)) == 0) gtk_main_quit();
}

static void on_window_title_changed(VteTerminal *vte, gpointer user_data) {
    GtkWidget *label = (GtkWidget *)user_data;
    const char *title = vte_terminal_get_window_title(vte);
    if (title) gtk_label_set_text(GTK_LABEL(label), title);
}

static void create_new_tab(AppData *app) {
    GtkWidget *term = vte_terminal_new();
    app->tab_counter++;

    // Tab Label Widget
    GtkWidget *hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    GtkWidget *lbl = gtk_label_new(g_strdup_printf("Tab %d", app->tab_counter));
    GtkWidget *btn = gtk_button_new_from_icon_name("window-close-symbolic", GTK_ICON_SIZE_MENU);
    gtk_button_set_relief(GTK_BUTTON(btn), GTK_RELIEF_NONE);
    gtk_box_pack_start(GTK_BOX(hbox), lbl, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(hbox), btn, FALSE, FALSE, 0);
    gtk_widget_show_all(hbox);

    // Apply Config
    apply_theme(VTE_TERMINAL(term), app->config.color_scheme);
    PangoFontDescription *fd = pango_font_description_from_string(app->config.font_name);
    pango_font_description_set_size(fd, app->config.font_size * PANGO_SCALE);
    vte_terminal_set_font(VTE_TERMINAL(term), fd);
    pango_font_description_free(fd);

    int idx = gtk_notebook_append_page(GTK_NOTEBOOK(app->notebook), term, hbox);
    
    // Signals
    g_signal_connect(term, "child-exited", G_CALLBACK(on_child_exited), app);
    g_signal_connect(term, "window-title-changed", G_CALLBACK(on_window_title_changed), lbl);
    g_signal_connect_swapped(btn, "clicked", G_CALLBACK(gtk_widget_destroy), term);

    char *sh[] = { g_getenv("SHELL") ? g_getenv("SHELL") : "/bin/bash", NULL };
    vte_terminal_spawn_async(VTE_TERMINAL(term), VTE_PTY_DEFAULT, NULL, sh, NULL, 0, NULL, NULL, NULL, -1, NULL, NULL, NULL);

    gtk_widget_show(term);
    gtk_notebook_set_current_page(GTK_NOTEBOOK(app->notebook), idx);
    gtk_widget_grab_focus(term);
}

/* --- Input Handling --- */

static gboolean check_kb(const char *cfg_str, GdkEventKey *ev) {
    guint val; GdkModifierType mod;
    gtk_accelerator_parse(cfg_str, &val, &mod);
    return (ev->keyval == val && (ev->state & gtk_accelerator_get_default_mod_mask()) == mod);
}

static gboolean on_key_press(GtkWidget *win, GdkEventKey *ev, AppData *app) {
    VteTerminal *term = VTE_TERMINAL(gtk_notebook_get_nth_page(GTK_NOTEBOOK(app->notebook), 
                        gtk_notebook_get_current_page(GTK_NOTEBOOK(app->notebook))));

    if (check_kb(app->config.key_new_tab, ev)) { create_new_tab(app); return TRUE; }
    if (check_kb(app->config.key_next_tab, ev)) { gtk_notebook_next_page(GTK_NOTEBOOK(app->notebook)); return TRUE; }
    if (check_kb(app->config.key_prev_tab, ev)) { gtk_notebook_prev_page(GTK_NOTEBOOK(app->notebook)); return TRUE; }
    if (check_kb(app->config.key_copy, ev)) { vte_terminal_copy_clipboard_format(term, VTE_FORMAT_TEXT); return TRUE; }
    if (check_kb(app->config.key_paste, ev)) { vte_terminal_paste_clipboard(term); return TRUE; }
    if (check_kb(app->config.key_close_tab, ev)) { gtk_widget_destroy(GTK_WIDGET(term)); return TRUE; }

    return FALSE;
}

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);
    AppData app = {0};

    // Hardcoded defaults (In a real app, read from file)
    app.config.window_width = 1000; app.config.window_height = 700;
    app.config.font_size = 12; strcpy(app.config.font_name, "Monospace");
    strcpy(app.config.color_scheme, "gruvbox");
    strcpy(app.config.key_new_tab, "<Control><Shift>t");
    strcpy(app.config.key_close_tab, "<Control><Shift>w");
    strcpy(app.config.key_next_tab, "<Control>Page_Down");
    strcpy(app.config.key_prev_tab, "<Control>Page_Up");
    strcpy(app.config.key_copy, "<Control><Shift>c");
    strcpy(app.config.key_paste, "<Control><Shift>v");

    app.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_default_size(GTK_WINDOW(app.window), app.config.window_width, app.config.window_height);

    // HeaderBar GUI
    GtkWidget *header = gtk_header_bar_new();
    gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(header), TRUE);
    gtk_header_bar_set_title(GTK_HEADER_BAR(header), "SVTE");
    GtkWidget *add_btn = gtk_button_new_from_icon_name("list-add-symbolic", GTK_ICON_SIZE_BUTTON);
    g_signal_connect_swapped(add_btn, "clicked", G_CALLBACK(create_new_tab), &app);
    gtk_header_bar_pack_start(GTK_HEADER_BAR(header), add_btn);
    gtk_window_set_titlebar(GTK_WINDOW(app.window), header);

    app.notebook = gtk_notebook_new();
    gtk_notebook_set_scrollable(GTK_NOTEBOOK(app.notebook), TRUE);
    gtk_container_add(GTK_CONTAINER(app.window), app.notebook);

    g_signal_connect(app.window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    g_signal_connect(app.window, "key-press-event", G_CALLBACK(on_key_press), &app);

    create_new_tab(&app);
    gtk_widget_show_all(app.window);
    gtk_main();
    return 0;
}