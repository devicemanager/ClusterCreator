#!/bin/bash

exec > >(tee /dev/console) 2>&1

set -a # automatically export all variables
source /etc/k8s.env
set +a # stop automatically exporting

chmod +x /root/*.sh

echo "Starting apt-packages.sh and source-packages.sh"

# These can run simultaneously because they don't depend on each other

/root/apt-packages.sh >> /var/log/template-firstboot-1-apt-packages.log 2>&1 &
pid1=$!
/root/source-packages.sh >> /var/log/template-firstboot-2-source-packages.log 2>&1 &
pid2=$!
/root/watch-disk-space.sh >/dev/null 2>&1 &
pid3=$!

echo "Waiting for apt-packages.sh and source-packages.sh to complete"

# wait for the first two to complete
wait $pid1 $pid2

echo "apt-packages.sh and source-packages.sh have completed"

# kill the third one, which would otherwise run indefinitely
kill $pid3

# cleanup
rm -f /root/apt-packages.sh /root/source-packages.sh /root/watch-disk-space.sh

echo "Firstboot script finished"

# signal to create_template_helper.sh that firstboot scripts are done
touch /tmp/.firstboot