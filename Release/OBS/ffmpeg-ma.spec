# Copyright (c) 2020 info@mediaarea.net
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.

# norootforbuild

%global _lto_cflags %nil

Name:           ffmpeg-ma
Version:        %VERSION%
Release:        1
Summary:        FFmpeg binary with patches from MediaArea.net
Group:          Productivity/Multimedia/Other
License:        GPL-3.0-or-later
URL:            https://mediaarea.net
Source0:        ffmpeg-ma_%{version}.tar.xz
Prefix:         %{_prefix}
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  nasm
BuildRequires:  cmake
BuildRequires:  meson
%if 0%{?suse_version}
BuildRequires:  ninja
%else
BuildRequires:  ninja-build
%endif
BuildRequires:  python3
BuildRequires:  pkgconf
BuildRequires:  zlib-devel
BuildRequires:  alsa-lib-devel
BuildRequires:  fontconfig-devel
%if 0%{?rhel} >= 8
BuildRequires:  alternatives
%endif

%description
FFmpeg binary with patches from MediaArea.net

%package devel
Summary:        Development files for %{name}
Group:          Development/Libraries/C and C++
Requires:       %{name} = %{version}-%{release}

%description devel
Development files (headers, pkg-config files and examples) for %{name}.

%prep
%setup -q -n ffmpeg

%build
export PATH=$PWD/output/bin:$PATH
export LIBRARY_PATH=$PWD/output/lib
export PKG_CONFIG_PATH=$PWD/output/lib/pkgconfig

meson setup --prefix $PWD/output --libdir lib --default-library=static -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled -Dpng=disabled -Dzlib=system freetype/build ../freetype
ninja -C freetype/build install

meson setup --prefix $PWD/output --libdir lib --default-library=static -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled -Dicu=disabled -Dgraphite=disabled -Dgraphite2=disabled -Dgdi=disabled -Ddirectwrite=disabled -Dcoretext=disabled -Dwasm=disabled -Dtests=disabled -Dintrospection=disabled -Ddocs=disabled -Ddoc_tests=false -Dutilities=disabled harfbuzz/build ../harfbuzz
ninja -C harfbuzz/build install
 
meson setup --prefix $PWD/output --libdir lib --default-library=static -Dtests=disabled openh264/builddir ../openh264
ninja -C openh264/builddir install
sed -i 's/-lopenh264/-lopenh264 -lstdc++/g' output/lib/pkgconfig/openh264.pc

meson setup  --prefix $PWD/output --libdir lib --default-library=static -Dbin=false -Ddocs=false -Dtests=false fribidi/build ../fribidi
ninja -C fribidi/build install

meson setup  --prefix $PWD/output --libdir lib --default-library=static -Dasm=enabled -Dfontconfig=enabled -Dlibunibreak=disabled -Dcompare=disabled -Dprofile=disabled -Dfuzz=disabled -Dcheckasm=disabled -Dtest=disabled ass/build ../ass
ninja -C ass/build install

cmake -B vulkan-headers/build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PWD/output ../vulkan-headers
ninja -C vulkan-headers/build install

cmake -B shaderc/build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PWD/output -DCMAKE_INSTALL_LIBDIR=lib -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON ../shaderc
ninja -C shaderc/build install

cmake -B sdl/build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PWD/output -DCMAKE_INSTALL_LIBDIR=lib -DSDL_STATIC=ON -DSDL_SHARED=OFF ../sdl
ninja -C sdl/build install

# Copy DeckLinkSDK include files
cp -r DeckLinkSDK/Linux/include/* output/include

./configure %BUILD_OPTIONS% \
    --enable-shared \
    --disable-static \
    --disable-stripping \
    --progs-suffix=-ma \
    --build-suffix=-ma \
    --prefix=%{_prefix} \
    --libdir=%{_libdir} \
    --incdir=%{_includedir}/%{name} \
    --datadir=%{_datadir}/%{name} \
    --disable-doc \
    --enable-alsa \
    --extra-cflags="-Ioutput/include" \
    --extra-cxxflags="-Ioutput/include" \
    --extra-ldflags="-lstdc++"
%__make

%install
%make_install
%__install -D -m 0644 patches/Release/HowToGPU.linux.txt %{buildroot}/%{_docdir}/%{name}/HowToGPU.txt
# The Makefile shipped with the examples refers to the upstream pkg-config names, add the -ma suffix
sed -i -E '/^FFMPEG_LIBS=/,/^[[:space:]]*$/ s/(libav(util|codec|format|device|filter)|libsw(scale|resample))/\1-ma/' %{buildroot}%{_datadir}/%{name}/examples/Makefile

%clean
[ -d "%{buildroot}" -a "%{buildroot}" != "" ] && %__rm -rf "%{buildroot}"

%files
%defattr(-,root,root,-)
%{_bindir}/ffmpeg-ma
%{_bindir}/ffprobe-ma
%{_bindir}/ffplay-ma
%{_libdir}/libav*-ma.so.*
%{_libdir}/libsw*-ma.so.*
%dir %{_datadir}/%{name}
%{_datadir}/%{name}/*.ffpreset
%{_datadir}/%{name}/ffprobe.xsd
%dir %{_docdir}/%{name}
%doc %{_docdir}/%{name}/HowToGPU.txt

%files devel
%defattr(-,root,root,-)
%{_includedir}/%{name}
%{_libdir}/libav*-ma.so
%{_libdir}/libsw*-ma.so
%{_libdir}/pkgconfig/libav*-ma.pc
%{_libdir}/pkgconfig/libsw*-ma.pc
%{_datadir}/%{name}/examples
