cmake_minimum_required(VERSION 3.15)
project(SimpleGraphic C CXX)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)

if (APPLE)
    enable_language(OBJCXX)
endif ()

if (MSVC)
    add_compile_options("/Zi")
    add_link_options("/DEBUG:FULL")
endif ()

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

include(${PROJECT_SOURCE_DIR}/vcpkg/scripts/buildsystems/vcpkg.cmake)

set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION ".")
include(InstallRequiredSystemLibraries)
add_subdirectory(dep/glm)

set(SIMPLEGRAPHIC_SOURCES
    "config.h"
    "dep/stb/stb_image.h"
    "dep/stb/stb_image_resize.h"
    "dep/stb/stb_image_write.h"
    "engine/common.h"
    "engine/common/base64.c"
    "engine/common/base64.h"
    "engine/common/common.cpp"
    "engine/common/console.cpp"
    "engine/common/console.h"
    "engine/common/keylist.h"
    "engine/common/memtrak3.cpp"
    "engine/common/memtrak3.h"
    "engine/common/streams.cpp"
    "engine/common/streams.h"
    "engine/core/core_compress.cpp"
    "engine/core/core_compress.h"
    "engine/core/core_config.cpp"
    "engine/core/core_config.h"
    "engine/core/core_image.cpp"
    "engine/core/core_image.h"
    "engine/core/core_main.cpp"
    "engine/core/core_main.h"
    "engine/core/core_tex_manipulation.cpp"
    "engine/core/core_tex_manipulation.h"
    "engine/core/core_video.cpp"
    "engine/core/core_video.h"
    "engine/render/r_font.cpp"
    "engine/render/r_font.h"
    "engine/render/r_main.cpp"
    "engine/render/r_main.h"
    "engine/render/r_texture.cpp"
    "engine/render/r_texture.h"
    "engine/system/win/sys_local.h"
    "engine/system/win/sys_main.cpp"
    "engine/system/win/sys_opengl.cpp"
    "engine/system/win/sys_video.cpp"
    "engine/system/sys_console.h"
    "engine/system/sys_main.h"
    "engine/system/sys_opengl.h"
    "engine/system/sys_video.h"
    "win/entry.cpp"
    "ui.h"
    "ui_api.cpp"
    "ui_console.cpp"
    "ui_console.h"
    "ui_debug.cpp"
    "ui_debug.h"
    "ui_local.h"
    "ui_main.cpp"
    "ui_main.h"
    "ui_subscript.cpp"
    "ui_subscript.h"
)

# Platform-specific sources — single if/elseif/else to avoid the earlier Apple
# block being silently overwritten by the WIN32/else block.
if (WIN32)
    set(SIMPLEGRAPHIC_PLATFORM_SOURCES
        "engine/system/win/sys_console.cpp"
        "SimpleGraphic.rc"
    )
elseif (APPLE)
    set(SIMPLEGRAPHIC_PLATFORM_SOURCES
        # Shared macOS helper (PlatformOpenURL via LSOpenCFURLRef)
        "engine/system/win/sys_macos.mm"
        # macOS-specific implementations added in feature/macos-port
        "engine/system/mac/sys_console.cpp"
        "engine/system/mac/sys_main.mm"
    )
else()
    set(SIMPLEGRAPHIC_PLATFORM_SOURCES
        "engine/system/win/sys_console_unix.cpp"
    )
endif()

add_library(SimpleGraphic SHARED
    ${SIMPLEGRAPHIC_SOURCES}
    ${SIMPLEGRAPHIC_PLATFORM_SOURCES}
)
target_compile_definitions(SimpleGraphic
    PRIVATE
    "UNICODE"
    "_CRT_SECURE_NO_DEPRECATE"
    "_CRT_SECURE_NO_WARNINGS"
    "_SCL_SECURE_NO_DEPRECATE"
    "_SCL_SECURE_NO_WARNINGS"
    "GLFW_INCLUDE_NONE"
    "GL_SILENCE_DEPRECATION"
    "SIMPLEGRAPHIC_EXPORTS"
)

target_include_directories(SimpleGraphic
    PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/engine"
)

find_package(unofficial-angle CONFIG REQUIRED)
find_package(CURL CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(glfw3 CONFIG REQUIRED)
find_package(gli CONFIG REQUIRED)
find_package(LuaJIT REQUIRED)
find_package(Microsoft.GSL CONFIG REQUIRED)
find_package(PkgConfig REQUIRED)
find_package(re2 CONFIG REQUIRED)
find_package(sol2 CONFIG REQUIRED)
find_package(Threads REQUIRED)
find_package(zstd REQUIRED)
find_package(ZLIB REQUIRED)
find_package(WebP)

add_library(cmp_core STATIC
    dep/compressonator/cmp_core/source/cmp_core.cpp
    dep/compressonator/cmp_core/source/cmp_core.h
    dep/compressonator/cmp_core/shaders/bc3_encode_kernel.cpp
    dep/compressonator/cmp_core/shaders/bc7_encode_kernel.cpp
)

target_include_directories(cmp_core PRIVATE
    dep/compressonator/applications/_libs/cmp_math
)

target_include_directories(cmp_core PUBLIC
    dep/compressonator/cmp_core/shaders
    dep/compressonator/cmp_core/source
)

add_library(imgui STATIC
    dep/imgui/imconfig.h
    dep/imgui/imgui.cpp
    dep/imgui/imgui.h
    dep/imgui/imgui_demo.cpp
    dep/imgui/imgui_draw.cpp
    dep/imgui/imgui_internal.h
    dep/imgui/imgui_tables.cpp
    dep/imgui/imgui_widgets.cpp
    dep/imgui/imstb_rectpack.h
    dep/imgui/imstb_textedit.h
    dep/imgui/imstb_truetype.h
    dep/imgui/backends/imgui_impl_glfw.cpp
    dep/imgui/backends/imgui_impl_glfw.h
    dep/imgui/backends/imgui_impl_opengl3.cpp
    dep/imgui/backends/imgui_impl_opengl3.h
    dep/imgui/backends/imgui_impl_opengl3_loader.h
    dep/imgui/misc/cpp/imgui_stdlib.cpp
    dep/imgui/misc/cpp/imgui_stdlib.h
)

target_compile_definitions(imgui PUBLIC
    "IMGUI_IMPL_OPENGL_ES2"
)

target_include_directories(imgui PUBLIC
    dep/imgui
    dep/imgui/backends
    dep/imgui/misc/cpp
)

target_link_libraries(imgui PUBLIC
    unofficial::angle::libGLESv2
    glfw
)

target_include_directories(SimpleGraphic
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/dep/glad/include
    ${CMAKE_CURRENT_SOURCE_DIR}/dep/stb
)

if (CMAKE_SYSTEM_NAME MATCHES "Linux")
    target_link_options(SimpleGraphic
        PRIVATE
        "-export-dynamic"
    )
endif ()

if (WIN32)
    target_compile_options(SimpleGraphic
        PRIVATE
        "/EHa"
    )
    target_compile_definitions(SimpleGraphic
        PRIVATE
        "_CRT_SECURE_NO_DEPRECATE=1"
        "_CRT_SECURE_NO_WARNINGS=1"
        "_SCL_SECURE_NO_DEPRECATE=1"
        "_SCL_SECURE_NO_WARNINGS=1"
    )
    target_link_libraries(SimpleGraphic
        PRIVATE
        "winmm.lib"
    )
endif ()

if (APPLE)
    find_library(CORE_FOUNDATION_LIBRARY CoreFoundation REQUIRED)
    find_library(APPLICATION_SERVICES_LIBRARY ApplicationServices REQUIRED)
    find_library(APPKIT_LIBRARY AppKit REQUIRED)
    find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
    find_library(METAL_LIBRARY Metal REQUIRED)
    find_library(QUARTZCORE_LIBRARY QuartzCore REQUIRED)
    target_link_libraries(SimpleGraphic
        PRIVATE
        ${CORE_FOUNDATION_LIBRARY}
        ${APPLICATION_SERVICES_LIBRARY}
        ${APPKIT_LIBRARY}       # NSTask / NSAlert in sys_main.mm
        ${FOUNDATION_LIBRARY}   # NSFileManager, NSURL, etc.
        ${METAL_LIBRARY}        # Required by ANGLE Metal backend
        ${QUARTZCORE_LIBRARY}   # Required by ANGLE Metal backend
    )
endif ()

target_link_libraries(SimpleGraphic
    PRIVATE
    unofficial::angle::libEGL
    unofficial::angle::libGLESv2
    cmp_core
    fmt::fmt
    glfw
    gli
    glm::glm
    imgui
    LuaJIT::LuaJIT
    Microsoft.GSL::GSL
    re2::re2
    sol2
    Threads::Threads
    WebP::webpdecoder
    ZLIB::ZLIB
    $<IF:$<TARGET_EXISTS:zstd::libzstd_shared>,zstd::libzstd_shared,zstd::libzstd_static>
)

# libSimpleGraphic needs @loader_path RPATH so that GLFW's
# dlopen("libEGL.dylib") finds the ANGLE dylibs sitting next to it.
if (APPLE)
    set_target_properties(SimpleGraphic PROPERTIES
        BUILD_RPATH "@loader_path"
        INSTALL_RPATH "@loader_path"
    )
endif ()

install(FILES $<TARGET_RUNTIME_DLLS:SimpleGraphic> DESTINATION ".")
install(TARGETS SimpleGraphic
    RUNTIME DESTINATION "."
    LIBRARY DESTINATION $<IF:$<BOOL:${APPLE}>,Frameworks,.>
)

# Install ANGLE shared libraries alongside SimpleGraphic (macOS only).
# GLFW calls dlopen("libEGL.dylib") at runtime; the dylib must be in
# the same directory as libSimpleGraphic.dylib so @loader_path finds it.
# The vcpkg angle port names them "liblibEGL_angle.dylib" (double prefix);
# we create symlinks with the names GLFW expects.
if (APPLE)
    set(_angle_lib_dir "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib")
    message(STATUS "ANGLE lib dir: ${_angle_lib_dir}")
    file(GLOB _angle_dylibs
        "${_angle_lib_dir}/lib*EGL*.dylib"
        "${_angle_lib_dir}/lib*GLESv2*.dylib")
    message(STATUS "ANGLE dylibs found: ${_angle_dylibs}")
    if (_angle_dylibs)
        install(FILES ${_angle_dylibs} DESTINATION Frameworks)
    endif ()

    # Create symlinks in the build directory so GLFW can find them at dev time.
    # Also create them at install time.
    # GLFW dlopen's "libEGL.dylib"; vcpkg produces "liblibEGL_angle.dylib".
    set(_angle_egl "${_angle_lib_dir}/liblibEGL_angle.dylib")
    set(_angle_gles "${_angle_lib_dir}/liblibGLESv2_angle.dylib")
    if (EXISTS "${_angle_egl}" AND EXISTS "${_angle_gles}")
        message(STATUS "ANGLE: will create symlinks for GLFW dlopen")
        add_custom_command(TARGET SimpleGraphic POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_angle_egl}" "$<TARGET_FILE_DIR:SimpleGraphic>/liblibEGL_angle.dylib"
            COMMAND ${CMAKE_COMMAND} -E create_symlink
                "liblibEGL_angle.dylib" "$<TARGET_FILE_DIR:SimpleGraphic>/libEGL.dylib"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_angle_gles}" "$<TARGET_FILE_DIR:SimpleGraphic>/liblibGLESv2_angle.dylib"
            COMMAND ${CMAKE_COMMAND} -E create_symlink
                "liblibGLESv2_angle.dylib" "$<TARGET_FILE_DIR:SimpleGraphic>/libGLESv2.dylib"
            COMMENT "Copying ANGLE dylibs and creating symlinks for GLFW"
        )
        install(CODE "
            execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
                \"liblibEGL_angle.dylib\"
                \"\${CMAKE_INSTALL_PREFIX}/Frameworks/libEGL.dylib\")
            execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
                \"liblibGLESv2_angle.dylib\"
                \"\${CMAKE_INSTALL_PREFIX}/Frameworks/libGLESv2.dylib\")
        ")
    else ()
        message(WARNING "ANGLE shared libraries not found — GLFW EGL init will fail")
    endif ()
endif ()

# ── macOS launcher executable ────────────────────────────────────────────────
# Builds a standalone Mach-O binary (Contents/MacOS/Path of Building-PoE2)
# that links SimpleGraphic.dylib and calls RunLuaFileAsWin.
if (APPLE)
    add_executable(PathOfBuilding
        "mac/entry.cpp"
    )
    target_include_directories(PathOfBuilding
        PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}/engine"
    )
    target_link_libraries(PathOfBuilding
        PRIVATE
        SimpleGraphic
    )
    set_target_properties(PathOfBuilding PROPERTIES
        OUTPUT_NAME "Path of Building-PoE2"
        BUILD_RPATH "@executable_path"
        INSTALL_RPATH "@executable_path/../Frameworks"
    )
    # Ad-hoc code signing — works without an Apple Developer account
    add_custom_command(TARGET PathOfBuilding POST_BUILD
        COMMAND codesign --force --sign - $<TARGET_FILE:PathOfBuilding>
        COMMENT "Ad-hoc code signing: Path of Building-PoE2"
    )
    install(TARGETS PathOfBuilding RUNTIME DESTINATION "MacOS")
endif ()
# ─────────────────────────────────────────────────────────────────────────────

if (WIN32)
    set(DEPS_DIR "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}")

    if (NOT VCPKG_TARGET_TRIPLET MATCHES "-release")
        find_file(LuaJIT_DLL_DEBUG NAMES "lua51.dll"
            PATHS "${DEPS_DIR}" PATH_SUFFIXES "debug/bin" REQUIRED NO_DEFAULT_PATH)
        find_file(ZLIB_DLL_DEBUG NAMES "zlibd1.dll"
            PATHS "${DEPS_DIR}" PATH_SUFFIXES "debug/bin" REQUIRED NO_DEFAULT_PATH)

        install(FILES
            ${LuaJIT_DLL_DEBUG}
            ${ZLIB_DLL_DEBUG}
            DESTINATION "."
            CONFIGURATIONS Debug
        )
    endif ()

    find_file(LuaJIT_DLL_RELEASE NAMES "lua51.dll"
        PATHS "${DEPS_DIR}" PATH_SUFFIXES "bin" REQUIRED NO_DEFAULT_PATH)
    find_file(ZLIB_DLL_RELEASE NAMES "zlib1.dll"
        PATHS "${DEPS_DIR}" PATH_SUFFIXES "bin" REQUIRED NO_DEFAULT_PATH)

    install(FILES
        ${LuaJIT_DLL_RELEASE}
        ${ZLIB_DLL_RELEASE}
        DESTINATION "."
        CONFIGURATIONS Release MinSizeRel RelWithDebInfo
    )
endif ()


# lcurl module

set(LCURL_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libs/Lua-cURLv3)
file(GLOB LCURL_SOURCES ${LCURL_SOURCE_DIR}/src/**.c)
add_library(lcurl SHARED ${LCURL_SOURCES})

target_include_directories(lcurl
    PRIVATE
    ${LCURL_SOURCE_DIR}/src
)

target_link_libraries(lcurl
    PRIVATE
    CURL::libcurl
    LuaJIT::LuaJIT
)

install(TARGETS lcurl
    RUNTIME DESTINATION "."
    LIBRARY DESTINATION $<IF:$<BOOL:${APPLE}>,Frameworks,.>
)
install(FILES $<TARGET_RUNTIME_DLLS:lcurl> DESTINATION ".")

# luautf8 module

add_library(lua-utf8 SHARED libs/luautf8/lutf8lib.c)

target_compile_definitions(lua-utf8
    PRIVATE
    $<$<BOOL:${WIN32}>:LUA_BUILD_AS_DLL>
)

# lutf8lib.c uses INT_MAX without including <limits.h>; force-include it on non-Windows.
target_compile_options(lua-utf8
    PRIVATE
    $<$<NOT:$<BOOL:${WIN32}>>:-include limits.h>
)

target_include_directories(lua-utf8
    PRIVATE
)

target_link_libraries(lua-utf8
    PRIVATE
    LuaJIT::LuaJIT
)

install(TARGETS lua-utf8
    RUNTIME DESTINATION "."
    LIBRARY DESTINATION $<IF:$<BOOL:${APPLE}>,Frameworks,.>
)
install(FILES $<TARGET_RUNTIME_DLLS:lua-utf8> DESTINATION ".")

# luasocket module

if (WIN32)
    set(LUASOCKET_PLATFORM_SOURCES "libs/luasocket/src/wsocket.c")
else()
    # usocket.c provides the POSIX socket back-end for macOS and Linux
    set(LUASOCKET_PLATFORM_SOURCES "libs/luasocket/src/usocket.c")
endif()

add_library(luasocket SHARED
   "libs/luasocket/src/auxiliar.c"
   "libs/luasocket/src/buffer.c"
   "libs/luasocket/src/compat.c"
   "libs/luasocket/src/except.c"
   "libs/luasocket/src/inet.c"
   "libs/luasocket/src/io.c"
   "libs/luasocket/src/luasocket.c"
   "libs/luasocket/src/options.c"
   "libs/luasocket/src/select.c"
   "libs/luasocket/src/tcp.c"
   "libs/luasocket/src/timeout.c"
   "libs/luasocket/src/udp.c"
   ${LUASOCKET_PLATFORM_SOURCES}
)

target_include_directories(luasocket
    PRIVATE
    ${LSOCKET_SOURCE_DIR}/src
)

target_link_libraries(luasocket
    PRIVATE
    LuaJIT::LuaJIT
)
if (WIN32)
    target_link_libraries(luasocket PRIVATE wsock32 ws2_32)
endif ()

set_target_properties( luasocket PROPERTIES OUTPUT_NAME "socket" )
install(TARGETS luasocket
    RUNTIME DESTINATION "."
    LIBRARY DESTINATION $<IF:$<BOOL:${APPLE}>,Frameworks,.>
)
install(FILES $<TARGET_RUNTIME_DLLS:luasocket> DESTINATION ".")

# lzip module

add_library(lzip SHARED libs/LZip/lzip.cpp)

target_include_directories(lzip
    PRIVATE
)

target_link_libraries(lzip
    PRIVATE
    LuaJIT::LuaJIT
    ZLIB::ZLIB
)

install(TARGETS lzip
    RUNTIME DESTINATION "."
    LIBRARY DESTINATION $<IF:$<BOOL:${APPLE}>,Frameworks,.>
)
install(FILES $<TARGET_RUNTIME_DLLS:lzip> DESTINATION ".")

# Lua C modules must be named <module>.so (no lib prefix) so LuaJIT's
# default package.cpath can find them on macOS.  Without this, CMake
# produces lib<module>.dylib which does not match ?.so patterns.
if (APPLE)
    set_target_properties(lcurl lzip lua-utf8 luasocket PROPERTIES
        PREFIX ""
        SUFFIX ".so"
    )
endif ()

