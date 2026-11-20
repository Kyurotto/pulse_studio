# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(music LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "music")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE -D_CRT_SECURE_NO_WARNINGS)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100" /wd"4996")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0" "_CRT_SECURE_NO_WARNINGS")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# If Firebase C++ SDK was extracted and specifies CMake 3.22+, patch it to 3.20 for VS 2019 compatibility.
set(_FIREBASE_SDK_DIR "${CMAKE_BINARY_DIR}/extracted/firebase_cpp_sdk_windows")
set(_FIREBASE_SDK_CMAKELISTS "${_FIREBASE_SDK_DIR}/CMakeLists.txt")
if(EXISTS "${_FIREBASE_SDK_CMAKELISTS}")
  file(READ "${_FIREBASE_SDK_CMAKELISTS}" _sdk_cmake)
  string(REPLACE "cmake_minimum_required(VERSION 3.22)" "cmake_minimum_required(VERSION 3.20)" _sdk_cmake "${_sdk_cmake}")
  string(REPLACE "set(FIREBASE_SDK_LIBDIR" "if(NOT EXISTS \"\${FIREBASE_CPP_SDK_DIR}/libs/windows/\${MSVC_VS_VERSION}/\${MSVC_RUNTIME_MODE}\")\n    set(MSVC_RUNTIME_MODE MT)\n  endif()\n  set(FIREBASE_SDK_LIBDIR" _sdk_cmake "${_sdk_cmake}")
  file(WRITE "${_FIREBASE_SDK_CMAKELISTS}" "${_sdk_cmake}")
  file(GLOB _REL_LIBS "${_FIREBASE_SDK_DIR}/libs/windows/VS2019/MT/x64/Release/*.lib")
  file(MAKE_DIRECTORY "${_FIREBASE_SDK_DIR}/libs/windows/VS2019/MT/x64/Debug")
  file(COPY ${_REL_LIBS} DESTINATION "${_FIREBASE_SDK_DIR}/libs/windows/VS2019/MT/x64/Debug")
  file(MAKE_DIRECTORY "${_FIREBASE_SDK_DIR}/libs/windows/VS2019/MD/x64/Debug")
  file(COPY ${_REL_LIBS} DESTINATION "${_FIREBASE_SDK_DIR}/libs/windows/VS2019/MD/x64/Debug")
  file(MAKE_DIRECTORY "${_FIREBASE_SDK_DIR}/libs/windows/VS2019/MD/x64/Release")
  file(COPY ${_REL_LIBS} DESTINATION "${_FIREBASE_SDK_DIR}/libs/windows/VS2019/MD/x64/Release")
endif()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
# Google Firebase C++ SDK requires VS 2022 toolset; strip firebase plugins on Windows
# when building with VS 2019 to avoid MSVC CRT ABI conflicts.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugins.cmake")
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugins.cmake" _gen_plugins)
  string(REGEX REPLACE "([ \t\r\n]+)(firebase_core|cloud_firestore|firebase_auth)" "" _gen_plugins "${_gen_plugins}")
  file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugins.cmake" "${_gen_plugins}")
endif()
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugin_registrant.cc")
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugin_registrant.cc" _reg_content)
  string(REGEX REPLACE "[ \t]*#include <(firebase_core|cloud_firestore|firebase_auth)/[^\n]*\n" "" _reg_content "${_reg_content}")
  string(REGEX REPLACE "[ \t]*(FirebaseCore|CloudFirestore|FirebaseAuth)PluginCApiRegisterWithRegistrar\\([^\n]*\n[ \t]*[^\n]*\\);\n" "" _reg_content "${_reg_content}")
  file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugin_registrant.cc" "${_reg_content}")
endif()
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "Install path" FORCE)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
