#!/bin/bash
# =============================================================================
# APISIX 3.15 Build Script for Air-Gapped RHEL 9 Install
# Run this on an internet-connected RHEL 9 EC2 build machine
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# Configuration — update these before running
# =============================================================================
APISIX_VERSION="3.15.0"
OPENRESTY_VERSION="1.29.2.3"
BASE_REPO="https://github.com/apache/apisix.git"
BRANCH="release/3.15"

GIT_USERNAME="${GIT_USERNAME:-sudheesh-nair}"
GIT_PAT="${GIT_PAT:-}"  # Set via environment: export GIT_PAT=your_token
FORK_REPO="https://${GIT_USERNAME}:${GIT_PAT}@github.com/${GIT_USERNAME}/apisix.git"

# Validate PAT is set
if [ -z "${GIT_PAT}" ]; then
  echo "ERROR: GIT_PAT is not set. Please export your GitHub Personal Access Token:"
  echo "  export GIT_PAT=your_token"
  exit 1
fi


echo "============================================="
echo " Step 1: Enable required repositories"
echo "============================================="

# Enable CodeReady Linux Builder (CRB) first — required for libyaml-devel
sudo dnf install -y 'dnf-command(config-manager)'
sudo dnf config-manager --set-enabled codeready-builder-for-rhel-9-rhui-rpms

# Enable EPEL
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm


echo "============================================="
echo " Step 2: Install system dependencies"
echo "============================================="

sudo dnf install -y \
  gcc gcc-c++ make curl wget unzip xz gnupg \
  perl-ExtUtils-Embed cpanminus patch \
  libyaml-devel perl perl-devel \
  pcre pcre-devel pcre2 pcre2-devel \
  openssl-devel zlib-devel \
  openldap-devel


echo "============================================="
echo " Step 3: Build and install OpenResty ${OPENRESTY_VERSION}"
echo "============================================="

cd ~
curl https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz -o openresty-${OPENRESTY_VERSION}.tar.gz
tar -xvf openresty-${OPENRESTY_VERSION}.tar.gz
cd openresty-${OPENRESTY_VERSION}/
./configure -j2
make -j2
sudo make install
export PATH=/usr/local/openresty/bin:$PATH
cd ~


echo "============================================="
echo " Step 4: Install OpenResty PCRE and zlib packages"
echo "============================================="

# Add OpenResty repo
curl -o /tmp/openresty.repo https://openresty.org/package/rhel/openresty.repo
sudo mv /tmp/openresty.repo /etc/yum.repos.d/openresty.repo

# Disable GPG check for OpenResty repo (SHA1 key incompatible with RHEL 9 strict crypto policy)
sudo sed -i 's/gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/openresty.repo

sudo dnf install -y openresty-pcre openresty-pcre-devel openresty-zlib openresty-zlib-devel


echo "============================================="
echo " Step 5: Clone APISIX base repo"
echo "============================================="

sudo dnf install -y git
cd ~
git clone ${BASE_REPO}
cd apisix
git fetch origin
git checkout -b ${BRANCH} origin/${BRANCH}


echo "============================================="
echo " Step 6: Run make deps"
echo "============================================="

make deps


echo "============================================="
echo " Step 7: Fix .gitignore to allow deps/"
echo "============================================="

# Remove 'deps' line from .gitignore
sed -i '/^deps/d' .gitignore

# Verify
echo "Current .gitignore contents:"
cat .gitignore


echo "============================================="
echo " Step 8: Add fork as remote"
echo "============================================="

git remote add myfork ${FORK_REPO}
git remote -v


echo "============================================="
echo " Step 9: Stage deps and log placeholder files"
echo "============================================="

# Force add deps folder including .so files
git add -f deps/

# Add empty log placeholder files
touch logs/error.log logs/access.log
git add logs/error.log logs/access.log

git commit -m "chore: add deps and log placeholders for air-gapped install of APISIX ${APISIX_VERSION}"


echo "============================================="
echo " Step 10: Extract dashboard UI from Docker image"
echo "============================================="

# Install podman if not already available
sudo dnf install -y podman

# Pull the official APISIX RedHat image
podman pull docker.io/apache/apisix:${APISIX_VERSION}-redhat

# Create a container and copy UI files out
podman create --name apisix-temp docker.io/apache/apisix:${APISIX_VERSION}-redhat
podman cp apisix-temp:/usr/local/apisix/ui .
podman rm apisix-temp


echo "============================================="
echo " Step 11: Commit and push all changes to fork"
echo "============================================="

git add ui/
git commit -m "chore: add dashboard UI files for air-gapped install of APISIX ${APISIX_VERSION}"
git push myfork ${BRANCH}

echo "============================================="
echo " Step 12: Bundle compiled OpenResty binary (optional)"
echo " Skip this step if OpenResty is already installed"
echo " on the target air-gapped VM"
echo "============================================="

cd ~/apisix
mkdir -p deps/openresty_${OPENRESTY_VERSION}
sudo cp -r /usr/local/openresty/. deps/openresty_${OPENRESTY_VERSION}/
git add -f deps/openresty_${OPENRESTY_VERSION}/
git commit -m "chore: add compiled OpenResty ${OPENRESTY_VERSION} binary for air-gapped install"
git push myfork ${BRANCH}

