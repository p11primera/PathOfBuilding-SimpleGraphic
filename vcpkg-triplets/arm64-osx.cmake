set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)

# Release-only: skip debug builds to cut ANGLE compile time roughly in half.
# For a developer debug build, remove this line or use the built-in triplet.
set(VCPKG_BUILD_TYPE release)
