set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

# ANGLE must be shared: GLFW calls dlopen("libEGL.dylib") at runtime to
# initialise EGL.  A statically-linked ANGLE gives no file for GLFW to open.
if(PORT MATCHES "angle")
    set(VCPKG_LIBRARY_LINKAGE dynamic)
endif()

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)

# Release-only: skip debug builds to cut ANGLE compile time roughly in half.
# For a developer debug build, remove this line or use the built-in triplet.
set(VCPKG_BUILD_TYPE release)

# Ensure every port (including make-based ones like LuaJIT) sees the active SDK.
# VCPKG_CMAKE_CONFIGURE_OPTIONS propagates into the cmake-get-vars probe project,
# so the compiler flag detection picks up the correct sysroot.
execute_process(COMMAND xcrun --show-sdk-path
    OUTPUT_VARIABLE VCPKG_OSX_SYSROOT OUTPUT_STRIP_TRAILING_WHITESPACE)
list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
    "-DCMAKE_OSX_ARCHITECTURES=arm64"
    "-DCMAKE_OSX_SYSROOT=${VCPKG_OSX_SYSROOT}"
)
