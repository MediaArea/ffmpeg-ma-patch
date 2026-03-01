##  Copyright (c) MediaArea.net SARL. All Rights Reserved.
##
##  Use of this source code is governed by a BSD-style license that can
##  be found in the License.html file in the root of the source tree.
##

Param(
    [String]$build_type = "static"
)

$ErrorActionPreference = "Stop"

#-----------------------------------------------------------------------
# Setup
$release_directory = $PSScriptRoot
$root_directory = "${release_directory}\..\..\.."
$output_directory = "${root_directory}\output"
$version = (Get-Content "${release_directory}\version.txt" -Raw).Trim()

$build_type_alt = "Static"
if ($build_type -Ne "static") {
    $build_type_alt = "Shared"
}

#-----------------------------------------------------------------------
# Cleanup
$artifact = "${root_directory}\FFmpeg_Bin_${version}_Windows_${build_type_alt}_x64.zip"
if (Test-Path "${artifact}") {
    Remove-Item -Force "${artifact}"
}

$artifact = "${root_directory}\FFmpeg_Dev_${version}_Windows_${build_type_alt}_x64.zip"
if (Test-Path "${artifact}") {
    Remove-Item -Force "${artifact}"
}

#-----------------------------------------------------------------------
# Package
Push-Location "${output_directory}"
    Copy-Item -Force "README.bin.txt" "README.txt"
    & 7za.exe a -tzip -mx9 "-xr!share\ffmpeg\examples" "${root_directory}\FFmpeg_Bin_${version}_Windows_${build_type_alt}_x64.zip" LICENSE.txt README.txt HowToGPU.txt bin share/ffmpeg patches
    Copy-Item -Force "README.dev.txt" "README.txt"
    if ($build_type -Eq "static") {
        & 7za.exe a -tzip -mx9 "-ir!include\libav*" "-ir!include\libsw*" -ir!lib "-ir!share\ffmpeg\examples" "${root_directory}\FFmpeg_Dev_${version}_Windows_${build_type_alt}_x64.zip" LICENSE.txt README.txt HowToGPU.txt patches
    }
    else {
        & 7za.exe a -tzip -mx9 "-ir!include\libav*" "-ir!include\libsw*" "-ir!lib\av*" "-ir!lib\sw*" "-ir!share\ffmpeg\examples" "${root_directory}\FFmpeg_Dev_${version}_Windows_${build_type_alt}_x64.zip" LICENSE.txt README.txt HowToGPU.txt patches
    }
Pop-Location
