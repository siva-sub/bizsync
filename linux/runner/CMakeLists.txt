cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

# Link Wayland libraries if available
if(WAYLAND_FOUND)
  target_link_libraries(${BINARY_NAME} PRIVATE ${WAYLAND_LIBRARIES})
  target_include_directories(${BINARY_NAME} PRIVATE ${WAYLAND_INCLUDE_DIRS})
  target_compile_options(${BINARY_NAME} PRIVATE ${WAYLAND_CFLAGS_OTHER})
endif()

# Link hardware acceleration libraries if available
if(EGL_FOUND AND EPOXY_FOUND)
  target_link_libraries(${BINARY_NAME} PRIVATE ${EGL_LIBRARIES} ${EPOXY_LIBRARIES})
  target_include_directories(${BINARY_NAME} PRIVATE ${EGL_INCLUDE_DIRS} ${EPOXY_INCLUDE_DIRS})
endif()

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
