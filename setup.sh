#!/bin/bash
set -eu -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR

# load environment variables from .env
set -a
if [ -e "$SCRIPT_DIR"/.env ]; then
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR"/.env
else
  echo 'Environment file .env not found. Therefore, dotenv.sample will be used.'
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR"/dotenv.sample
fi
set +a

readonly FILE="$SCRIPT_DIR/oracle-database-xe-21c-1.0-1.ol7.x86_64.rpm"
readonly CHECKSUM=4c8f40a19d4d1a2f00e46df022943a04cc13fe62aed27c4c66a137e72f513c36

# Verify SHA256 checksum
echo "$CHECKSUM $FILE" | sha256sum -c

# Install the database software
yum -y localinstall "$FILE"

# Creating and Configuring an Oracle Database
echo -e "${ORACLE_PASSWORD}\n${ORACLE_PASSWORD}" | /etc/init.d/oracle-xe-21c configure

# Set environment variables
cat <<EOT >>/home/vagrant/.bash_profile
export ORACLE_BASE=/opt/oracle/product/21c/dbhomeXE
export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
export ORACLE_SID=XE
export PATH=\$PATH:\$ORACLE_HOME/bin
EOT

# Install rlwrap and set alias
yum -y --enablerepo=ol7_developer_EPEL install rlwrap
cat <<EOT >>/home/vagrant/.bashrc
alias sqlplus='rlwrap sqlplus'
EOT

# Automating Shutdown and Startup
systemctl daemon-reload
systemctl enable oracle-xe-21c

# Install the Sample Schemas
if [[ ${ORACLE_SAMPLESCHEMA^^} == TRUE ]]; then
  SAMPLE_DIR=$(mktemp -d)
  readonly SAMPLE_DIR
  chmod 777 "$SAMPLE_DIR"
  cp "$SCRIPT_DIR"/install_sample.sh "$SAMPLE_DIR"/install_sample.sh
  su - vagrant -c "$SAMPLE_DIR/install_sample.sh $ORACLE_PASSWORD localhost/xepdb1"
  su - vagrant -c "rm -rf $SAMPLE_DIR/*"
  rmdir "$SAMPLE_DIR"
fi
