#!/bin/sh
{
  date
  id
  SCRIPT_DIR=/media/internal/downloads IPK_SRC=/media/internal/downloads/hbchannel.ipk
  export SCRIPT_DIR IPK_SRC
  /bin/sh /media/internal/downloads/autoroot.sh --curl-insecure --leave-script
  rc=$?
  echo "autoroot rc=$rc"
  id
} > /tmp/root-install.log 2>&1
chmod 666 /tmp/root-install.log
