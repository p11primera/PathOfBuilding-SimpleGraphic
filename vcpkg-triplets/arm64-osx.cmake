set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)

# Release-only: skip debug builds to cut ANGLE compile time roughly in half.
# For a developer debug build, remove this line or use the built-in triplet.
set(VCPKG_BUILD_TYPE release)

# Ensure every port (including make-based ones like LuaJIT) sees the active SDK.
# Without this, vcpkg_cmake_get_vars produces "-isysroot <empty>" which breaks
# any Makefile port that calls <string.h> etc.
# Use VCPKG_OSX_SYSROOT instead of VCPKG_CMAKE_CONFIGURE_OPTIONS to avoid
# clobbering vcpkg's internal -DCMAKE_OSX_ARCHITECTURES=arm64 injection.
execute_process(COMMAND xcrun --show-sdk-path
    OUTPUT_VARIABLE VCPKG_OSX_SYSROOT OUTPUT_STRIP_TRAILING_WHITESPACE)
