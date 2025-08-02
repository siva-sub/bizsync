#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif
#include <stdlib.h>
#include <string.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Check if Mesa software rendering is being used
static gboolean is_mesa_software_rendering() {
  const char* renderer = getenv("LIBGL_ALWAYS_SOFTWARE");
  if (renderer != nullptr && strcmp(renderer, "1") == 0) {
    return TRUE;
  }
  
  // Check GL_RENDERER if available
  const char* gl_renderer = getenv("GL_RENDERER");
  if (gl_renderer != nullptr) {
    if (strstr(gl_renderer, "llvmpipe") != nullptr ||
        strstr(gl_renderer, "softpipe") != nullptr ||
        strstr(gl_renderer, "swrast") != nullptr) {
      return TRUE;
    }
  }
  
  return FALSE;
}

// Configure environment for Mesa software rendering to avoid flicker
static void configure_mesa_rendering() {
  if (is_mesa_software_rendering()) {
    // Disable vsync for software rendering to avoid flicker
    setenv("vblank_mode", "0", 1);
    
    // Use simpler rendering path
    setenv("LIBGL_DRI3_DISABLE", "1", 1);
    
    // Disable compositor bypass
    setenv("CLUTTER_PAINT", "disable-clipped-redraws:disable-culling", 1);
    
    // Additional Mesa-specific optimizations
    // Disable GLSL optimizations that can cause issues with software rendering
    setenv("MESA_GLSL_CACHE_DISABLE", "1", 1);
    
    // Use the simplest shader variants
    setenv("MESA_SHADER_CACHE_DISABLE", "1", 1);
    
    // Disable threaded OpenGL to avoid synchronization issues
    setenv("mesa_glthread", "false", 1);
    
    // Disable GPU memory cache which can cause flickering
    setenv("MESA_NO_MEMOBJ_CACHE", "1", 1);
    
    // Force synchronous rendering to avoid frame drops
    setenv("MESA_DEBUG", "flush", 1);
    
    // Disable texture compression for better compatibility
    setenv("force_s3tc_enable", "false", 1);
    
    // Set Mesa extension override to disable problematic extensions
    setenv("MESA_EXTENSION_OVERRIDE", "-GL_ARB_buffer_storage -GL_EXT_buffer_storage", 1);
    
    // Force single-threaded rendering
    setenv("LP_NUM_THREADS", "1", 1);
    
    // Disable FBO cache which can cause rendering issues
    setenv("MESA_FBO_CACHE", "0", 1);
    
    // Force X11 backend if on Wayland with software rendering
    const char* gdk_backend = getenv("GDK_BACKEND");
    if (gdk_backend == nullptr || strcmp(gdk_backend, "wayland") == 0) {
      // Only force X11 if we're sure it's available
      GdkDisplay* display = gdk_display_get_default();
      if (display != nullptr) {
        #ifdef GDK_WINDOWING_X11
        if (GDK_IS_X11_DISPLAY(display)) {
          setenv("GDK_BACKEND", "x11", 1);
        }
        #endif
      }
    }
    
    g_print("BizSync: Mesa software rendering detected, applying comprehensive workarounds\n");
    g_print("  - Disabled vsync (vblank_mode=0)\n");
    g_print("  - Disabled DRI3 (LIBGL_DRI3_DISABLE=1)\n");
    g_print("  - Disabled GLSL cache\n");
    g_print("  - Single-threaded rendering (LP_NUM_THREADS=1)\n");
    g_print("  - Synchronous flushing enabled\n");
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Wayland-optimized window configuration
  // Set window properties for better Wayland compatibility
  gtk_window_set_resizable(window, TRUE);
  gtk_window_set_decorated(window, TRUE);
  
  // Detect display backend and configure accordingly
  GdkDisplay* display = gdk_display_get_default();
  gboolean use_header_bar = TRUE;
  gboolean is_wayland = FALSE;
  
#ifdef GDK_WINDOWING_WAYLAND
  if (GDK_IS_WAYLAND_DISPLAY(display)) {
    is_wayland = TRUE;
    // On Wayland, always use header bar for better integration
    use_header_bar = TRUE;
    
    // Set Wayland-specific window hints for smoother rendering
    gtk_window_set_type_hint(window, GDK_WINDOW_TYPE_HINT_NORMAL);
    
    // Enable compositing for smooth animations
    gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
  }
#endif

#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_DISPLAY(display)) {
    GdkScreen* screen = gtk_window_get_screen(window);
    if (GDK_IS_X11_SCREEN(screen)) {
      const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
      if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
        use_header_bar = FALSE;
      }
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "bizsync");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "bizsync");
  }

  gtk_window_set_default_size(window, 1280, 720);
  
  // Wayland-specific optimizations
#ifdef GDK_WINDOWING_WAYLAND
  if (is_wayland) {
    // Set minimum size to prevent rendering issues
    gtk_widget_set_size_request(GTK_WIDGET(window), 800, 600);
    
    // Double buffering is now automatic in GTK3, no need to set explicitly
    // gtk_widget_set_double_buffered was deprecated in GTK 3.14
  }
#endif
  
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  
  // Configure Flutter view for Wayland
#ifdef GDK_WINDOWING_WAYLAND
  if (is_wayland) {
    // Enable hardware acceleration when available
    gtk_widget_set_can_focus(GTK_WIDGET(view), TRUE);
    gtk_widget_set_receives_default(GTK_WIDGET(view), TRUE);
    
    // Set up for optimal rendering
    gtk_widget_set_app_paintable(GTK_WIDGET(view), TRUE);
  }
#endif
  
  // Apply Mesa software rendering workarounds to Flutter view
  if (is_mesa_software_rendering()) {
    // Disable double buffering to reduce flicker with software rendering
    // Note: gtk_widget_set_double_buffered is deprecated, using app_paintable instead
    gtk_widget_set_app_paintable(GTK_WIDGET(view), FALSE);
    
    // Request simpler visual to avoid complex compositing
    GdkVisual* visual = gdk_screen_get_system_visual(gtk_widget_get_screen(GTK_WIDGET(window)));
    if (visual) {
      gtk_widget_set_visual(GTK_WIDGET(window), visual);
      gtk_widget_set_visual(GTK_WIDGET(view), visual);
    }
  }
  
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.
  
  // Configure Mesa rendering workarounds before Flutter initializes
  configure_mesa_rendering();

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
