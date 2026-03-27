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
OPENRESTY_VERSION="1.27.1.2"
BASE_REPO="https://github.com/apache/apisix.git"
BRANCH="release/3.15"

GIT_USERNAME="${GIT_USERNAME:-sudheesh-nair}"
GIT_EMAIL="${GIT_EMAIL:-}"  # Set via environment: export GIT_EMAIL=your_email
GIT_PAT="${GIT_PAT:-}"  # Set via environment: export GIT_PAT=your_token
FORK_REPO="https://${GIT_USERNAME}:${GIT_PAT}@github.com/${GIT_USERNAME}/apisix.git"

# Validate PAT is set
if [ -z "${GIT_PAT}" ]; then
  echo "ERROR: GIT_PAT is not set. Please export your GitHub Personal Access Token:"
  echo "  export GIT_PAT=your_token"
  exit 1
fi

# Validate email is set
if [ -z "${GIT_EMAIL}" ]; then
  echo "ERROR: GIT_EMAIL is not set. Please export your GitHub email:"
  echo "  export GIT_EMAIL=your_email"
  exit 1
fi

# Configure git
git config --global user.name "${GIT_USERNAME}"
git config --global user.email "${GIT_EMAIL}"


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
  gcc gcc-c++ make git curl wget unzip xz gnupg \
  perl-ExtUtils-Embed cpanminus patch \
  libyaml-devel perl perl-devel \
  pcre pcre-devel pcre2 pcre2-devel \
  openssl-devel zlib-devel \
  openldap-devel podman luarocks


echo "============================================="
echo " Step 3: Extract OpenResty ${OPENRESTY_VERSION} from APISIX Docker image"
echo "============================================="

# Pull the official APISIX RedHat image
podman pull docker.io/apache/apisix:${APISIX_VERSION}-redhat

# Extract OpenResty directly into deps folder
podman create --name openresty-temp docker.io/apache/apisix:${APISIX_VERSION}-redhat
mkdir -p ~/apisix/deps/openresty_${OPENRESTY_VERSION}
podman cp openresty-temp:/usr/local/openresty ~/apisix/deps/openresty_${OPENRESTY_VERSION}/
podman rm openresty-temp

# Rename the nested folder if needed
if [ -d ~/apisix/deps/openresty_${OPENRESTY_VERSION}/openresty ]; then
  mv ~/apisix/deps/openresty_${OPENRESTY_VERSION}/openresty/* ~/apisix/deps/openresty_${OPENRESTY_VERSION}/
  rm -rf ~/apisix/deps/openresty_${OPENRESTY_VERSION}/openresty
fi

# Install to correct path (OpenResty binaries have hardcoded paths to /usr/local/openresty)
sudo cp -r ~/apisix/deps/openresty_${OPENRESTY_VERSION}/. /usr/local/openresty/

# Fix the broken symlink
sudo ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/local/openresty/bin/openresty

# Add to PATH
export PATH=/usr/local/openresty/bin:$PATH
echo 'export PATH=/usr/local/openresty/bin:$PATH' >> ~/.bashrc

# Verify
openresty -v


echo "============================================="
echo " Step 4: Configure luarocks to use OpenResty LuaJIT"
echo "============================================="

# Configure system luarocks to use OpenResty's LuaJIT
luarocks config lua_interpreter luajit
luarocks config lua_dir /usr/local/openresty/luajit
luarocks config lua_incdir /usr/local/openresty/luajit/include/luajit-2.1
luarocks config lua_libdir /usr/local/openresty/luajit/lib

# Verify
luarocks config | grep lua_dir


echo "============================================="
echo " Step 5: Clone APISIX base repo"
echo "============================================="

cd ~
git clone ${BASE_REPO}
cd apisix
git fetch origin
git checkout -b ${BRANCH} origin/${BRANCH}


echo "============================================="
echo " Step 6: Run make deps ENV_LUAROCKS="luarocks --lua-version 5.1""
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

# Force add deps folder including .so files in lib64
git add -f deps/

# Add empty log placeholder files
mkdir -p logs
touch logs/error.log logs/access.log
git add -f logs/error.log logs/access.log

git commit -m "chore: add deps and log placeholders for air-gapped install of APISIX ${APISIX_VERSION}"
git push myfork ${BRANCH}


echo "============================================="
echo " Step 10: Extract dashboard UI from Docker image"
echo "============================================="

# Create a container and copy UI files out
podman create --name apisix-temp docker.io/apache/apisix:${APISIX_VERSION}-redhat
podman cp apisix-temp:/usr/local/apisix/ui .
podman rm apisix-temp

git add ui/
git commit -m "chore: add dashboard UI files for air-gapped install of APISIX ${APISIX_VERSION}"
git push myfork ${BRANCH}


echo "============================================="
echo " Done! All changes pushed to fork on branch ${BRANCH}"
echo "=============================================
"
