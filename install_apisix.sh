#!/bin/bash
# =============================================================================
# APISIX 3.15 Install Script using forked git repo
# Run this on a fresh RHEL 9 EC2 VM to verify air-gapped install
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# Configuration
# =============================================================================
APISIX_VERSION="3.15.0"
OPENRESTY_VERSION="1.27.1.2"
GIT_USERNAME="${GIT_USERNAME:-sudheesh-nair}"
APISIX_ADMIN_KEY="${APISIX_ADMIN_KEY:-}"  # Set via environment: export APISIX_ADMIN_KEY=your_key
FORK_REPO="https://github.com/${GIT_USERNAME}/apisix.git"
BRANCH="release/3.15"
APISIX_DIR="/usr/local/apisix"
LUADIR="/usr/local/share/lua/5.1"

# Validate admin key is set
if [ -z "${APISIX_ADMIN_KEY}" ]; then
  echo "ERROR: APISIX_ADMIN_KEY is not set. Please export your APISIX admin key:"
  echo "  export APISIX_ADMIN_KEY=your_key"
  exit 1
fi


echo "============================================="
echo " Step 1: Install git"
echo "============================================="

sudo dnf install -y git


echo "============================================="
echo " Step 2: Clone repo and install OpenResty"
echo "============================================="

# Clone the repo
git clone -b ${BRANCH} ${FORK_REPO} ~/apisix
cd ~/apisix

# Copy OpenResty to system path
sudo cp -r deps/openresty_${OPENRESTY_VERSION}/. /usr/local/openresty/

# Fix symlink
sudo ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/local/openresty/bin/openresty

# Add to PATH
export PATH=/usr/local/openresty/bin:$PATH
echo 'export PATH=/usr/local/openresty/bin:$PATH' >> ~/.bashrc

# Verify
openresty -v


echo "============================================="
echo " Step 3: Install APISIX files"
echo "============================================="

cd ~/apisix

# Create directories
sudo install -d ${APISIX_DIR}/
sudo install -d ${APISIX_DIR}/logs/
sudo install -d ${APISIX_DIR}/conf/cert
sudo mkdir -p ${APISIX_DIR}/logs

# Copy conf files
sudo install conf/mime.types ${APISIX_DIR}/conf/mime.types
sudo install conf/config.yaml ${APISIX_DIR}/conf/config.yaml
sudo install conf/debug.yaml ${APISIX_DIR}/conf/debug.yaml
sudo install conf/cert/* ${APISIX_DIR}/conf/cert/

# Copy all Lua source files to both required locations
sudo mkdir -p ${LUADIR}
sudo cp -r apisix ${LUADIR}/
sudo cp -r apisix ${APISIX_DIR}/

# Copy deps, UI and bin
sudo cp -r deps ${APISIX_DIR}/
sudo cp -r ui ${APISIX_DIR}/
sudo cp -r bin ${APISIX_DIR}/


echo "============================================="
echo " Step 4: Configure standalone mode (no etcd)"
echo "============================================="

# Configure APISIX to use standalone yaml mode instead of etcd
sudo tee /usr/local/apisix/conf/config.yaml > /dev/null <<EOF
deployment:
  role: traditional
  role_traditional:
    config_provider: yaml
  admin:
    enable_admin_ui: true
    allow_admin:
      - 127.0.0.0/24
    admin_key:
      - key: ${APISIX_ADMIN_KEY}
        name: admin
        role: admin
EOF

# Create minimal apisix.yaml config
sudo tee /usr/local/apisix/conf/apisix.yaml > /dev/null <<EOF
routes: []
#END
EOF


echo "============================================="
echo " Step 5: Configure systemd service"
echo "============================================="

sudo tee /usr/lib/systemd/system/apisix.service > /dev/null <<EOF
[Unit]
Description=Apache APISIX
After=network.target

[Service]
Type=forking
WorkingDirectory=/usr/local/apisix
LimitNOFILE=65535
Environment="PATH=/usr/local/openresty/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="LUA_PATH=/usr/local/apisix/deps/share/lua/5.1/?.lua;/usr/local/apisix/deps/share/lua/5.1/?/init.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;;"
Environment="LUA_CPATH=/usr/local/apisix/deps/lib64/lua/5.1/?.so;/usr/local/apisix/deps/lib/lua/5.1/?.so;;"
ExecStart=/usr/local/apisix/bin/apisix start
ExecStop=/usr/local/apisix/bin/apisix stop
ExecReload=/usr/local/apisix/bin/apisix reload
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable apisix


echo "============================================="
echo " Step 6: Start APISIX"
echo "============================================="

sudo systemctl start apisix
sudo systemctl status apisix

echo "============================================="
echo " Done! APISIX ${APISIX_VERSION} is running"
echo "============================================="

