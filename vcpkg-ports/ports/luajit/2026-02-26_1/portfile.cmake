set(extra_patches "")
if (VCPKG_TARGET_IS_OSX)
	list(APPEND extra_patches 005-do-not-pass-ld-e-macosx.patch)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO LuaJIT/LuaJIT
    REF a553b3de243b1ae07bdb21da4bdab77148793f76  #2026-02-26
    SHA512 5c504989e6a0726277143ecb1eb25e08e20803141dd5cfe83ea716b23bde2542e21310ae350da34ef3b3a10f4709e45426f7ad05ef08983dd01f370b83199dac
    HEAD_REF v2.1
    PATCHES
        msvcbuild.patch
        003-do-not-set-macosx-deployment-target.patch
        007-fix-void-return-mcode-setprot.patch
        pob-wide-crt.patch
        006-fix-getenvcopy-null-guard.patch
        ${extra_patches}
)

vcpkg_cmake_get_vars(cmake_vars_file)
include("${cmake_vars_file}")

# On macOS, the cmake-vars probe (used by vcpkg_configure_make) may detect an
# empty CMAKE_OSX_SYSROOT and embed a bare "-isysroot " in the flags like:
#   VCPKG_DETECTED_CMAKE_C_FLAGS_RELEASE "-fPIC -arch arm64 -isysroot   -O3 -DNDEBUG"
# This breaks make-based builds with "string.h: No such file or directory".
#
# vcpkg_configure_make calls z_vcpkg_get_cmake_vars internally and includes the
# resulting cmake-vars-<triplet>{,-rel}.cmake.log file.  We need those files to
# contain a real sysroot path.
if(VCPKG_TARGET_IS_OSX)
    execute_process(
        COMMAND xcrun --show-sdk-path
        OUTPUT_VARIABLE _osx_sdk
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(_osx_sdk)
        set(_dst_rel "${CURRENT_BUILDTREES_DIR}/cmake-vars-${TARGET_TRIPLET}-rel.cmake.log")
        # vcpkg_cmake_get_vars writes cmake-get-vars_C_CXX-<triplet>-rel.cmake.log
        # (the _C_CXX configuration suffix is derived from the default C+CXX language list).
        set(_src_rel "${CURRENT_BUILDTREES_DIR}/cmake-get-vars_C_CXX-${TARGET_TRIPLET}-rel.cmake.log")

        # Helper macro: patch a cmake vars file so that bare " -isysroot " is replaced
        # with " -isysroot <real_sdk_path> ".  Appends set() overrides at the end of
        # the file so they win over any earlier broken set() calls.
        macro(z_luajit_patch_cmake_vars_file _pfile)
            if(EXISTS "${_pfile}")
                file(READ "${_pfile}" _fc)
                # Skip if already patched
                string(FIND "${_fc}" "z_luajit_sysroot_fixed" _already_patched)
                if(_already_patched EQUAL -1)
                    set(_patch_lines "# z_luajit_sysroot_fixed: sysroot corrected by LuaJIT portfile\n")
                    # Process known flag variables that may contain a broken -isysroot.
                    # We read each variable's current value from the cmake file using regex
                    # (set(VARNAME "value")) and rewrite it with a real sysroot.
                    foreach(_vn
                        VCPKG_DETECTED_CMAKE_C_FLAGS
                        VCPKG_DETECTED_CMAKE_C_FLAGS_RELEASE
                        VCPKG_DETECTED_CMAKE_CXX_FLAGS
                        VCPKG_DETECTED_CMAKE_CXX_FLAGS_RELEASE
                        VCPKG_DETECTED_RAW_CMAKE_C_FLAGS
                        VCPKG_DETECTED_RAW_CMAKE_CXX_FLAGS
                        VCPKG_DETECTED_CMAKE_SHARED_LINKER_FLAGS
                        VCPKG_DETECTED_CMAKE_SHARED_LINKER_FLAGS_RELEASE
                        VCPKG_DETECTED_CMAKE_EXE_LINKER_FLAGS
                        VCPKG_DETECTED_CMAKE_EXE_LINKER_FLAGS_RELEASE
                        VCPKG_DETECTED_CMAKE_MODULE_LINKER_FLAGS
                        VCPKG_DETECTED_CMAKE_MODULE_LINKER_FLAGS_RELEASE
                        VCPKG_DETECTED_RAW_CMAKE_SHARED_LINKER_FLAGS
                        VCPKG_DETECTED_RAW_CMAKE_EXE_LINKER_FLAGS
                        VCPKG_COMBINED_C_FLAGS_RELEASE
                        VCPKG_COMBINED_CXX_FLAGS_RELEASE
                        VCPKG_COMBINED_SHARED_LINKER_FLAGS_RELEASE
                        VCPKG_COMBINED_EXE_LINKER_FLAGS_RELEASE
                    )
                        # Extract the value from the last set(<vn> "...") line in the file
                        string(REGEX MATCH "set\\(${_vn} \"([^\"]*)\"\\)" _vmatch "${_fc}")
                        if(_vmatch)
                            set(_vv "${CMAKE_MATCH_1}")
                            # Check if value contains -isysroot (may be bare or with a path)
                            string(FIND "${_vv}" "-isysroot" _has_sysroot)
                            if(NOT _has_sysroot EQUAL -1)
                                # Two-pass strip of -isysroot:
                                # Pass 1: strip "-isysroot /real/path" (space + path starting with /)
                                string(REGEX REPLACE " -isysroot /[^ ]*" "" _vv "${_vv}")
                                # Pass 2: strip bare " -isysroot" and any trailing spaces that
                                # immediately follow (handles both end-of-string and spaces before next flag)
                                string(REGEX REPLACE " -isysroot *" " " _vv "${_vv}")
                                string(STRIP "${_vv}" _vv)
                                # Append with correct sysroot
                                string(APPEND _patch_lines "set(${_vn} \"${_vv} -isysroot ${_osx_sdk}\")\n")
                            endif()
                        endif()
                    endforeach()
                    string(APPEND _fc "${_patch_lines}")
                    file(WRITE "${_pfile}" "${_fc}")
                endif()
            endif()
        endmacro()

        # Patch the rel file that z_vcpkg_get_cmake_vars uses.
        # If it doesn't exist yet, seed it from the cmake-get-vars rel file first.
        if(NOT EXISTS "${_dst_rel}" AND EXISTS "${_src_rel}")
            file(READ "${_src_rel}" _seed_content)
            file(WRITE "${_dst_rel}" "${_seed_content}")
        endif()
        z_luajit_patch_cmake_vars_file("${_dst_rel}")

        # Also patch the cmake-get-vars rel file (used by portfile's include above)
        z_luajit_patch_cmake_vars_file("${_src_rel}")

        # Create wrapper files for both code paths in z_vcpkg_get_cmake_vars:
        #   cmake-vars-<triplet>.cmake.log         (VCPKG_BUILD_TYPE undefined in function scope)
        #   cmake-vars-<triplet>-release.cmake.log (VCPKG_BUILD_TYPE="release")
        foreach(_wrapper_name
            "cmake-vars-${TARGET_TRIPLET}.cmake.log"
            "cmake-vars-${TARGET_TRIPLET}-release.cmake.log"
        )
            set(_wrapper "${CURRENT_BUILDTREES_DIR}/${_wrapper_name}")
            # Use absolute path in include to avoid CMAKE_CURRENT_LIST_DIR scope issues
            file(WRITE "${_wrapper}" "include(\"${_dst_rel}\")\n")
        endforeach()

        # Pre-set both cache variables so z_vcpkg_get_cmake_vars skips regeneration
        set(Z_VCPKG_GET_CMAKE_VARS_FILE
            "${CURRENT_BUILDTREES_DIR}/cmake-vars-${TARGET_TRIPLET}.cmake.log"
            CACHE PATH "Pre-fixed cmake vars (LuaJIT)" FORCE)
        set(Z_VCPKG_GET_CMAKE_VARS_FILE_release
            "${CURRENT_BUILDTREES_DIR}/cmake-vars-${TARGET_TRIPLET}-release.cmake.log"
            CACHE PATH "Pre-fixed cmake vars release (LuaJIT)" FORCE)
    endif()
endif()


if(VCPKG_DETECTED_MSVC)
    # Due to lack of better MSVC cross-build support, just always build the host
    # minilua tool with the target toolchain. This will work for native builds and
    # for targeting x86 from x64 hosts. (UWP and ARM64 is unsupported.)
    vcpkg_list(SET options)
    set(PKGCONFIG_CFLAGS "")
    if (VCPKG_LIBRARY_LINKAGE STREQUAL "static")
        list(APPEND options "MSVCBUILD_OPTIONS=static")
    else()
        set(PKGCONFIG_CFLAGS "/DLUA_BUILD_AS_DLL=1")
    endif()

    vcpkg_install_nmake(SOURCE_PATH "${SOURCE_PATH}"
        PROJECT_NAME "${CMAKE_CURRENT_LIST_DIR}/Makefile.nmake"
        OPTIONS
            ${options}
    )

    configure_file("${CMAKE_CURRENT_LIST_DIR}/luajit.pc.win.in" "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/luajit.pc" @ONLY)
    if(NOT VCPKG_BUILD_TYPE)
        configure_file("${CMAKE_CURRENT_LIST_DIR}/luajit.pc.win.in" "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/luajit.pc" @ONLY)
    endif()

    vcpkg_copy_pdbs()
else()
    vcpkg_list(SET options)
    if(VCPKG_CROSSCOMPILING)
        list(APPEND options
            "LJARCH=${VCPKG_TARGET_ARCHITECTURE}"
            "BUILDVM_X=${CURRENT_HOST_INSTALLED_DIR}/manual-tools/${PORT}/buildvm-${VCPKG_TARGET_ARCHITECTURE}${VCPKG_HOST_EXECUTABLE_SUFFIX}"
        )
    endif()

    vcpkg_list(SET make_options "EXECUTABLE_SUFFIX=${VCPKG_TARGET_EXECUTABLE_SUFFIX}")
    set(strip_options "") # cf. src/Makefile
    if(VCPKG_TARGET_IS_OSX)
        vcpkg_list(APPEND make_options "TARGET_SYS=Darwin")
        set(strip_options " -x")
    elseif(VCPKG_TARGET_IS_IOS)
        vcpkg_list(APPEND make_options "TARGET_SYS=iOS")
        set(strip_options " -x")
    elseif(VCPKG_TARGET_IS_LINUX)
        vcpkg_list(APPEND make_options "TARGET_SYS=Linux")
    elseif(VCPKG_TARGET_IS_WINDOWS)
        vcpkg_list(APPEND make_options "TARGET_SYS=Windows")
        set(strip_options " --strip-unneeded")
    endif()

    set(dasm_archs "")
    if("buildvm-32" IN_LIST FEATURES)
        string(APPEND dasm_archs " arm x86")
    endif()
    if("buildvm-64" IN_LIST FEATURES)
        string(APPEND dasm_archs " arm64 x64")
    endif()

    # On macOS 11+ ARM64, enable the hardened-runtime JIT support so LuaJIT
    # uses MAP_JIT + pthread_jit_write_protect_np for executable memory.
    # Without this, mcode allocation fails on Apple Silicon (W^X policy).
    set(xcflags "")
    set(target_cflags "")
    if(VCPKG_TARGET_IS_OSX)
        string(APPEND xcflags " -DLUAJIT_ENABLE_OSX_HRT")
        # vcpkg_configure_make doesn't propagate -arch to CFLAGS for make-based
        # builds, so LuaJIT's Makefile detects the host architecture (x86_64 under
        # Rosetta) rather than the target.  Pass the arch explicitly.
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(target_cflags "-arch arm64")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(target_cflags "-arch x86_64")
        endif()
    endif()

    file(COPY "${CMAKE_CURRENT_LIST_DIR}/configure" DESTINATION "${SOURCE_PATH}")
    vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}"
        COPY_SOURCE
        NO_DEBUG
        OPTIONS
            "BUILDMODE=${VCPKG_LIBRARY_LINKAGE}"
            "XCFLAGS=${xcflags}"
            ${options}
        OPTIONS_RELEASE
            "DASM_ARCHS=${dasm_archs}"
    )
    vcpkg_install_make(
        MAKEFILE "Makefile.vcpkg"
        OPTIONS
            ${make_options}
            "TARGET_CFLAGS=${target_cflags}"
            "TARGET_LDFLAGS=${target_cflags}"
            "TARGET_AR=${VCPKG_DETECTED_CMAKE_AR} rcus"
            "TARGET_STRIP=${VCPKG_DETECTED_CMAKE_STRIP}${strip_options}"
    )
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/lib/lua"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/lib/lua"
    "${CURRENT_PACKAGES_DIR}/share/lua"
    "${CURRENT_PACKAGES_DIR}/share/man"
)

# On macOS the LuaJIT Makefile creates a circular bin/luajit -> luajit symlink
# when INSTALL_TNAME == LUAJIT_T (both "luajit"). Remove the broken bin/ entry;
# PoB only needs libluajit-5.1.a + headers, not the CLI binary.
if(VCPKG_TARGET_IS_OSX)
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin")
else()
    vcpkg_copy_tools(TOOL_NAMES luajit AUTO_CLEAN)
endif()

vcpkg_fixup_pkgconfig()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYRIGHT")
