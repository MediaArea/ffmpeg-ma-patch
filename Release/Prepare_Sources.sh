#!/bin/bash

##  Copyright (c) MediaArea.net SARL. All Rights Reserved.
##
##  Use of this source code is governed by a BSD-style license that can
##  be found in the License.html file in the root of the source tree.
##

set -e

#-----------------------------------------------------------------------
# Setup
release_directory="$(readlink -f "$(dirname "${BASH_SOURCE}")")"
version="${1}"
sources="ffmpeg"
build_options="$(<"${release_directory}/configure_options.txt")"

if [[ -e "${version}" ]] ; then
    echo "usage: ${0} <version>"
    exit 1
fi

#-----------------------------------------------------------------------
# Cleaning
pushd "${release_directory}"
    rm -f ffmpeg-ma_${version}.tar.xz
    rm -f ffmpeg-ma_${version}.7z
popd


#-----------------------------------------------------------------------
# Upgrade version
pushd "${release_directory}"
    echo "${version}" > version.txt
popd

#-----------------------------------------------------------------------
# Upgrade OBS project
pushd "${release_directory}"
    sed -i "s|%VERSION%|${version}|g" OBS/ffmpeg-ma.spec
    sed -i "s|%VERSION%|${version}|g" OBS/ffmpeg-ma.dsc
    sed -i "s|%VERSION%|${version}|g" OBS/PKGBUILD
    sed -i "s|%BUILD_OPTIONS%|${build_options}|g" OBS/ffmpeg-ma.spec
    sed -i "s|%BUILD_OPTIONS%|${build_options}|g" OBS/debian.rules
    sed -i "s|%BUILD_OPTIONS%|${build_options}|g" OBS/PKGBUILD
popd

#-----------------------------------------------------------------------
# Upgrade changelogs
date_rfc2822="$(LC_ALL=C date -u -R)"
debian_changelog="${release_directory}/OBS/debian.changelog"
cat - <<EOF > "${debian_changelog}.new"
ffmpeg-ma (${version}-1) stable; urgency=medium

  * Update to ffmpeg ${version}

 -- MediaArea CI <info@mediaarea.net>  ${date_rfc2822}

EOF
sed -i "1e cat ${debian_changelog}.new" "${debian_changelog}"
rm -f "${debian_changelog}.new"

date_rpm="$(LC_ALL=C date -u '+%a %b %e %Y' | sed 's/  / /g')"
rpm_changelog="${release_directory}/OBS/ffmpeg-ma.changes"
cat - <<EOF > "${rpm_changelog}.new"
* ${date_rpm} MediaArea CI <info@mediaarea.net> - ${version}
- Update to ffmpeg ${version}

EOF
sed -i "1e cat ${rpm_changelog}.new" "${rpm_changelog}"
rm -f "${rpm_changelog}.new"

#-----------------------------------------------------------------------
# Get missing dependencies
pushd "${release_directory}/../../.."
    while read line ; do
        directory=$(echo "${line}" | cut -d: -f1)
        url=$(echo "${line}" | cut -d: -f2-)
        archive="${url##*/}"
        if [[ -z "${directory}" || -z "${url}" ]] ; then
            continue
        fi
        if [[ ! -e "${directory}" ]] ; then
            mkdir "${directory}"
            pushd "${directory}"
                curl -LO "${url}"
                tar --extract --strip-components=1 --file=${archive}
                rm -f ${archive}
            popd
        fi
        sources="${sources} ${directory}"
    done < "${release_directory}/dependencies.txt"
popd

#-----------------------------------------------------------------------
# Update shaderc submodule
pushd "${release_directory}/../../../shaderc"
    python3 utils/git-sync-deps
popd

#-----------------------------------------------------------------------
# Apply patches
pushd "${release_directory}/../.."
    for patch in patches/*.patch ; do
        if [ -e "${patch}" ] ; then
            patch -p1 < "${patch}"
        fi
    done
popd

#-----------------------------------------------------------------------
# Prepare sources
pushd "${release_directory}/../../.."
    rm -fr */.git*
    rm -fr ffmpeg/patches/.git*

    XZ_OPT=-9e tar -cJ --owner=root --group=root -f ffmpeg-ma_${version}.tar.xz ${sources}
    7za a -t7z -mx=9 -bd ffmpeg-ma_${version}.7z ${sources}
popd
