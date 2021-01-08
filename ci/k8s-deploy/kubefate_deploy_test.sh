#!/bin/bash
dir=$(cd $(dirname $0) && pwd)
source $dir/color.sh

source $dir/common.sh

if check_kubectl; then
  echo -e "$INFO: kubectl ready"
else
  exit 1
fi

if kubefate_install; then
  echo -e "$INFO: kubefate install success"
else
  exit 1
fi

set_host

if check_kubefate_version; then
  echo -e "$INFO: kubefate CLI ready"
else
  exit 1
fi

kubefate_uninstall

clean_host

echo -e "$INFO: kubefate_deploy_test done."

exit 0
