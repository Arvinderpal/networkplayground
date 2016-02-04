#!/bin/bash

# HOST1: 
# ./ipsec_simple.sh 1 172.16.60.219 172.16.60.220
# HOST2: 
# ./ipsec_simple.sh 2 172.16.60.219 172.16.60.220

SRCIP=$2
DSTIP=$3

echo "Setting up a Simple AH and ESP ipsec tunnel"

set -e

case $1 in
1)
setkey -c << EOF
	flush;
	spdflush;
	# Add authentication header (ah)	
	add $SRCIP $DSTIP ah 15700 -A hmac-md5 "1234567890123456"; 
	add $DSTIP $SRCIP ah 24500 -A hmac-md5 "1234567890123456"; 
	# Add encap security payload (esp) 
	add $SRCIP $DSTIP esp 15701 -E 3des-cbc "123456789012123456789012"; 
	add $DSTIP $SRCIP esp 24501 -E 3des-cbc "123456789012123456789012"; 
	# Add security policy (SP): everthing going *out* to DST must go over IPSEC and requires both ESP and AH
	spdadd $SRCIP $DSTIP any -P out ipsec esp/transport//require ah/transport//require;
	# Add security policy (SP): any traffic coming *in* from DST is required to have valid ESP and AH. 
	spdadd $DSTIP $SRCIP any -P in ipsec esp/transport//require ah/transport//require;
EOF
	;;
2)
setkey -c << EOF
	flush;
	spdflush;
	# Add authentication header (ah)	
	add $SRCIP $DSTIP ah 15700 -A hmac-md5 "1234567890123456"; 
	add $DSTIP $SRCIP ah 24500 -A hmac-md5 "1234567890123456"; 
	# Add encap security payload (esp) 
	add $SRCIP $DSTIP esp 15701 -E 3des-cbc "123456789012123456789012"; 
	add $DSTIP $SRCIP esp 24501 -E 3des-cbc "123456789012123456789012"; 
	# Add security policy (SP): everthing going *out* to SRC must go over IPSEC and requires both ESP and AH
	spdadd $DSTIP $SRCIP any -P out ipsec esp/transport//require ah/transport//require;
	# Add security policy (SP): any traffic coming *in* from SRC is required to have valid ESP and AH. 
	spdadd $SRCIP $DSTIP any -P in ipsec esp/transport//require ah/transport//require;
EOF
	;;


*)
	echo Usage: ./ipsec_simple.sh source_ip destination_ip 
    ;;
esac

echo "Done"