#!/bin/bash

set -e

if [ "$1" = 'splunk' ]; then
  shift
  sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk "$@"
elif [ "$1" = 'start-service' ]; then
  # If user changed SPLUNK_USER to root we want to change permission for SPLUNK_HOME
  if [[ "${SPLUNK_USER}:${SPLUNK_GROUP}" != "$(stat --format %U:%G ${SPLUNK_HOME})" ]]; then
    chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} ${SPLUNK_HOME}
  fi

  # If these files are different override etc folder (possible that this is upgrade or first start cases)
  # Also override ownership of these files to splunk:splunk
  if ! $(cmp --silent /var/opt/splunk/etc/splunk.version ${SPLUNK_HOME}/etc/splunk.version); then
    cp -fR /var/opt/splunk/etc ${SPLUNK_HOME}
    chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} ${SPLUNK_HOME}/etc
    chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} ${SPLUNK_HOME}/var
  fi
  
  # Add default admin creds - something that popped up recently
  if [[ ! -d $SPLUNK_HOME/etc/system/local ]] ; then
    mkdir -p $SPLUNK_HOME/etc/system/local
  fi
  cat <<EOF > $SPLUNK_HOME/etc/system/local/user-seed.conf
[user_info]
USERNAME = admin
PASSWORD = changeme
EOF

  if ! [[ "$SPLUNK_START_ARGS" == *"--accept-license"* ]]; then
    cat << EOF
    use the --accept-license argument on launch
EOF
    exit 1
  fi

  # Fix OSX file system mounts
  sed -i '/OPTIMISTIC_ABOUT_FILE_LOCKING/d' ${SPLUNK_HOME}/etc/splunk-launch.conf ; echo "OPTIMISTIC_ABOUT_FILE_LOCKING=1" >> ${SPLUNK_HOME}/etc/splunk-launch.conf

  # Just run splunk
  sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk start ${SPLUNK_START_ARGS}
  trap "sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME}/bin/splunk stop" SIGINT SIGTERM EXIT

  sudo -HEu ${SPLUNK_USER} tail -n 0 -f ${SPLUNK_HOME}/var/log/splunk/splunkd_stderr.log &
  wait
else
  "$@"
fi
