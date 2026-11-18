#!/bin/sh
{
  date
  id
  uname -a
} > /tmp/root-probe-result 2>&1
chmod 666 /tmp/root-probe-result
