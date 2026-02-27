vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/re2
    REF "${VERSION}"
    SHA512 c6a75cd77450b0859944497c197b69678a718d4b5234f0a5adc5524d0e113c1260b150b3fe99a7bfb87e96008eaedc7880dd851ddcf6ce9a4eee1409536c0482
    HEAD_REF master
)

# Force release-only build even if VCPKG_BUILD_TYPE is unset in function scope.
set(VCPKG_BUILD_TYPE release)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DRE2_BUILD_TESTING=OFF
        -Dabsl_DIR=${CURRENT_INSTALLED_DIR}/share/absl
        -DCMAKE_FIND_USE_CMAKE_SYSTEM_PATH=OFF
        # Ensure vcpkg headers come before Apple clang's implicit /usr/local/include
        -DCMAKE_CXX_FLAGS=-I${CURRENT_INSTALLED_DIR}/include
        -DCMAKE_C_FLAGS=-I${CURRENT_INSTALLED_DIR}/include
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/${PORT}")
vcpkg_fixup_pkgconfig()

vcpkg_copy_pdbs()

# Handle copyright
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
