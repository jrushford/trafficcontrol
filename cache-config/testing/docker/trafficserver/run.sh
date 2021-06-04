#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

die() {
  { test -n "$@" && echo "$@"; exit 1; } >&2
}

# Initialize the build directories
(
  mkdir -p /opt/build/jansson /opt/build/cjose /opt/build/openssl /opt/build/luacrypto
  cp -far /opt/{src,build}/jansson
  cp -far /opt/{src,build}/cjose
  cp -far /opt/{src,build}/openssl
  cp -far /opt/{src,build}/luacrypto  


  # prep build environment
  [ -e /rpmbuild ] && rm -rf /rpmbuild
  [ ! -e /rpmbuild ] || { echo "Failed to clean up rpm build directory 'rpmbuild': $?" >&2; exit 1; }
  mkdir -p /rpmbuild/{BUILD,BUILDROOT,RPMS,SPECS,SOURCES,SRPMS} || { echo "Failed to create build directory '$RPMBUILD': $?" >&2;
  exit 1; }
) || die "Failed to setup the build environment"

case ${ATS_VERSION:0:1} in
  8) cp /trafficserver-8.spec /rpmbuild/trafficserver.spec
     ;;
  9) cp /trafficserver-9.spec /rpmbuild/trafficserver.spec
     ;;
  *) echo "Unknown trafficserver version was specified"
     exit 1
     ;;
esac

echo "Building a RPM for ATS version: $ATS_VERSION"

# add the 'ats' user
id ats &>/dev/null || /usr/sbin/useradd -u 176 -r ats -s /sbin/nologin -d /

# setup the environment to use the devtoolset-9 tools.
source scl_source enable devtoolset-9 

# Build OpenSSL
(
	cd /opt/build/openssl && \
	./config --prefix=/opt/trafficserver/openssl --openssldir=/opt/trafficserver/openssl zlib && \
	make -j`nproc` && \
	make install_sw
) || die "Failed to build OpenSSL"

(cd /opt/build/jansson && patch -p1 < /opt/src/jansson.pic.patch && autoreconf -i && ./configure --enable-shared=no && make -j`nproc` && make install) || die "Failed to install jansson from source."
(cd /opt/build/cjose && patch -p1 < /opt/src/cjose.pic.patch && autoreconf -i && ./configure --enable-shared=no --with-openssl=/opt/trafficserver/openssl && make -j`nproc` && make install) || die "Failed to install cjose from source."
(cd /opt/build/luacrypto && ./configure LDFLAGS=-lluajit-5.1 && make) || die "Failed to install luacrypto from source."

cd /opt/rpmbuild/SOURCES
# clone the trafficserver repo
git clone https://github.com/apache/trafficserver.git

# build trafficserver version 9
rm -f /opt/rpmbuild/RPMS/x86_64/trafficserver-*.rpm
cd trafficserver
git fetch --all
git checkout $ATS_VERSION
rpmbuild -bb /trafficserver.spec

echo "Build completed"

if [[ ! -d /trafficcontrol/dist ]]; then
  mkdir /trafficcontrol/dist
fi

case ${ATS_VERSION:0:1} in
  8) cp /opt/rpmbuild/RPMS/x86_64/trafficserver-8*.rpm /trafficcontrol/dist
     ;;
  9) cp /opt/rpmbuild/RPMS/x86_64/trafficserver-8*.rpm /trafficcontrol/dist
     ;;
  *) echo "Unknown trafficserver version was specified"
     exit 1
     ;;
esac 


