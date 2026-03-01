##  Copyright (c) MediaArea.net SARL. All Rights Reserved.
##
##  Use of this source code is governed by a BSD-style license that can
##  be found in the License.html file in the root of the source tree.
##

Param([String]$build_type = "static")

$ErrorActionPreference = "Stop"

function Assert-Success([String]$step) {
    if ($LASTEXITCODE -ne 0) {
        throw "${step} failed (exit code ${LASTEXITCODE})"
    }
}

#-----------------------------------------------------------------------
# Setup
$release_directory = $PSScriptRoot
$root_directory = "${release_directory}\..\..\.."
$build_directory = "${root_directory}\build"
$output_directory = "${root_directory}\output"
$output_directory_posix = $output_directory -Replace '\\', '/'

$build_options = (Get-Content "${release_directory}\configure_options.txt" -Raw).Trim() -Split '\s+'
$build_options = $build_options | Where-Object { $_ -Ne "--enable-decklink" } # Disable DeckLink support for Windows (not working)

$build_type = $build_type.ToLower()
if ($build_type -Eq "static") {
    $build_options += "--enable-static", "--disable-shared"
}
else {
    $build_type = "shared"
    $build_options += "--disable-static", "--enable-shared"
}
$build_options += "--toolchain=msvc", "--enable-cross-compile", "--extra-libs=msvcrt.lib", "--extra-cflags=-I${output_directory_posix}/include", "--extra-cxxflags=-I${output_directory_posix}/include"
$build_options += "--glslc=glslc.exe" # Use host's glslc executable

$Env:PKG_CONFIG_PATH = "${output_directory}\lib\pkgconfig"
$Env:WSLENV = "INCLUDE:LIB:LIBPATH:PKG_CONFIG_PATH/p"

#-----------------------------------------------------------------------
# Cleanup
if (Test-Path "${build_directory}") {
    Remove-Item -Force -Recurse "${build_directory}"
}

if (Test-Path "${output_directory}") {
    Remove-Item -Force -Recurse "${output_directory}"
}

#-----------------------------------------------------------------------
# Build zlib
New-Item -Force -ItemType Directory "${build_directory}\zlib\build"
Push-Location "${build_directory}\zlib\build"
    cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DZLIB_BUILD_STATIC=ON -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_MINIZIP=OFF -DCMAKE_INSTALL_PREFIX="${output_directory}" "${root_directory}\zlib"
    Assert-Success "cmake (zlib)"
    ninja install
    Assert-Success "ninja install (zlib)"
Pop-Location

(Get-Content -Raw "${output_directory}\lib\pkgconfig\zlib.pc") -Replace "-lz", "-lzs" | Set-Content -Path "${output_directory}\lib\pkgconfig\zlib.pc"

#-----------------------------------------------------------------------
# Build freetype
New-Item -Force -ItemType Directory "${build_directory}\freetype\build"
Push-Location "${build_directory}\freetype\build"
    meson setup --prefix "${output_directory}" --buildtype=release --default-library=static -Db_vscrt=mt -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled -Dpng=disabled -Dzlib=internal "${root_directory}\freetype"
    Assert-Success "meson setup (freetype)"
    ninja install
    Assert-Success "ninja install (freetype)"
Pop-Location

#-----------------------------------------------------------------------
# Build harfbuzz
New-Item -Force -ItemType Directory "${build_directory}\harfbuzz\build"
Push-Location "${build_directory}\harfbuzz\build"
    meson setup --prefix "${output_directory}" --buildtype=release --default-library=static -Db_vscrt=mt -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled -Dicu=disabled -Dgraphite=disabled -Dgraphite2=disabled -Dgdi=disabled -Ddirectwrite=disabled -Dcoretext=disabled -Dwasm=disabled -Dtests=disabled -Dintrospection=disabled -Ddocs=disabled -Ddoc_tests=false -Dutilities=disabled "${root_directory}\harfbuzz"
    Assert-Success "meson setup (harfbuzz)"
    ninja install
    Assert-Success "ninja install (harfbuzz)"
Pop-Location

#-----------------------------------------------------------------------
# Build fribidi
New-Item -Force -ItemType Directory "${build_directory}\fribidi\build"
Push-Location "${build_directory}\fribidi\build"
    meson setup --prefix "${output_directory}" --buildtype=release --default-library=static -Db_vscrt=mt -Dbin=false -Ddocs=false -Dtests=false "${root_directory}\fribidi"
    Assert-Success "meson setup (fribidi)"
    ninja install
    Assert-Success "ninja install (fribidi)"
Pop-Location

#-----------------------------------------------------------------------
# Build ass
New-Item -Force -ItemType Directory "${build_directory}\ass\build"
Push-Location "${build_directory}\ass\build"
    meson setup --prefix "${output_directory}" --buildtype=release --default-library=static -Db_vscrt=mt -Dasm=enabled -Dfontconfig=disabled -Dlibunibreak=disabled -Ddirectwrite=enabled -Dcompare=disabled -Dprofile=disabled -Dtest=disabled -Dfuzz=disabled -Dcheckasm=disabled "${root_directory}\ass"
    Assert-Success "meson setup (ass)"
    ninja install
    Assert-Success "ninja install (ass)"
Pop-Location

#-----------------------------------------------------------------------
# Build openh264
New-Item -Force -ItemType Directory "${build_directory}\openh264\build"
Push-Location "${build_directory}\openh264\build"
    meson setup --prefix "${output_directory}" --buildtype=release --default-library=static -Db_vscrt=mt -Dtests=disabled "${root_directory}\openh264"
    Assert-Success "meson setup (openh264)"
    ninja install
    Assert-Success "ninja install (openh264)"
Pop-Location

#-----------------------------------------------------------------------
# Build vulkan-headers
New-Item -Force -ItemType Directory "${build_directory}\vulkan-headers\build"
Push-Location "${build_directory}\vulkan-headers\build"
    cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${output_directory}" "${root_directory}\vulkan-headers"
    Assert-Success "cmake (vulkan-headers)"
    ninja install
    Assert-Success "ninja install (vulkan-headers)"
Pop-Location

#-----------------------------------------------------------------------
# Build sdl
New-Item -Force -ItemType Directory "${build_directory}\sdl\build"
Push-Location "${build_directory}\sdl\build"
    cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${output_directory}" -DSDL_STATIC=ON -DSDL_SHARED=OFF "${root_directory}\sdl"
    Assert-Success "cmake (sdl)"
    ninja install
    Assert-Success "ninja install (sdl)"
Pop-Location

#-----------------------------------------------------------------------
# Build DeckLinkSDK headers
#New-Item -Force -ItemType Directory "${build_directory}\decklink"
#Push-Location "${build_directory}\decklink"
#    midl.exe /nologo /env x64 /I "${root_directory}\ffmpeg\DeckLinkSDK\Win\include" /h DeckLinkAPI.h /iid DeckLinkAPI_i.c /proxy NUL /dlldata NUL "${root_directory}\ffmpeg\DeckLinkSDK\Win\include\DeckLinkAPI.idl"
#    Assert-Success "midl (DeckLinkAPI)"

#    Set-Content -Path "DeckLinkAPI.h" -Value (@("#include <windows.h>", "#include <ole2.h>") + (Get-Content -Path "DeckLinkAPI.h"))
#    Copy-Item -Force "DeckLinkAPI.h" "DeckLinkAPI_v14_2_1.h"

#    Copy-Item -Force "DeckLinkAPI.h" "${output_directory}\include"
#    Copy-Item -Force "DeckLinkAPI_v14_2_1.h" "${output_directory}\include"
#    Copy-Item -Force "DeckLinkAPI_i.c" "${output_directory}\include"
#    Copy-Item -Force "DeckLinkAPIVersion.h" "${output_directory}\include"
#Pop-Location
#-----------------------------------------------------------------------
# Fix library and pkgconfig file names for MSVC toolchain
Get-ChildItem "${output_directory}\lib\lib*.a" | Rename-Item -NewName { $_.Name -Replace '^lib', '' -Replace '\.a$', '.lib' }

Get-ChildItem "${output_directory}\lib\pkgconfig\*.pc" | ForEach-Object {
    (Get-Content -Raw $_.FullName) -Replace "`r`n", "`n" | Set-Content -Path $_.FullName
}

#-----------------------------------------------------------------------
# Build ffmpeg
Push-Location "${root_directory}\ffmpeg"
    wsl --shell-type standard -- sed -i "'s/LNK4044|//g'" configure
    Assert-Success "sed (ffmpeg configure)"

    wsl --shell-type standard -- ./configure --prefix='"$PWD/../output"' @build_options
    Assert-Success "ffmpeg configure"

    wsl --shell-type standard -- make install
    Assert-Success "ffmpeg make install"
Pop-Location

#-----------------------------------------------------------------------
# Prepare output directory
Push-Location "${output_directory}"
    Get-ChildItem -Recurse -Filter "*.a" | Rename-Item -NewName { $_.Name -Replace '\.a$', '.lib' }

    if (Test-Path "lib\pkgconfig") {
        Remove-Item -Force -Recurse "lib\pkgconfig"
    }
    if (Test-Path "lib\cmake") {
        Remove-Item -Force -Recurse "lib\cmake"
    }
    if (Test-Path "bin\*.lib") {
        Move-Item "bin\*.lib" "lib" -Force
    }

    New-Item -Force -ItemType Directory "patches"
    Copy-Item -Force "${root_directory}\ffmpeg\patches\*.patch" "patches"
    Copy-Item -Force "${root_directory}\ffmpeg\COPYING.GPLv3" "LICENSE.txt"
    Copy-Item -Force "${root_directory}\ffmpeg\patches\Release\HowToGPU.windows.txt" "HowToGPU.txt"

    $patches_list = ((Get-ChildItem "${root_directory}\ffmpeg\patches\*.patch").Name -join "`n ")
    $options_list = ("${build_options}" -Replace ' ', "`n ")

    $readme = Get-Content "${root_directory}\ffmpeg\patches\Release\ReadMe.txt" -Raw
    $readme = $readme -Replace '%VERSION%', "${version}"
    $readme = $readme -Replace '%BUILD_OPTIONS%', "${options_list}"
    $readme = $readme -Replace '%BUILD_TYPE%', "${build_type}"
    $readme = $readme -Replace '%BUILD_ARCH%', "x64"
    $readme = $readme -Replace '%BUILD_OS%', "Windows"
    $readme = $readme -Replace '%PATCHES%', "${patches_list}"
    $readme_bin = $readme -Replace '%PACKAGE_TYPE%', "binaries"
    $readme_dev = $readme -Replace '%PACKAGE_TYPE%', "development files"

    Set-Content -Path "README.bin.txt" -Value $readme_bin
    Set-Content -Path "README.dev.txt" -Value $readme_dev
Pop-Location
