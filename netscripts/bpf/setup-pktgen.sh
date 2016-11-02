#!/bin/bash

for f in functions.sh parameters.sh pktgen_sample03_burst_single_flow.sh; do
  wget https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/plain/samples/pktgen/$f
done
chmod +x pktgen_sample*.sh
