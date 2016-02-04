#!/bin/bash

# HOST1: 
# ./ipsec_simple.sh 1 172.16.60.219 172.16.60.220
# HOST2: 
# ./ipsec_simple.sh 2 172.16.60.219 172.16.60.220

SRCIP=$2
DSTIP=$3

echo "Setting up a AH and ESP ipsec tunnel using Racoon & Shared Secret"

# NOTE: ADD THIS TO /etc/racoon/racoon.conf
# NOTE: file should be owned by root, and set to mode 0600
# path pre_shared_key "/usr/local/etc/racoon/psk.txt";
# remote anonymous 
# {
#  	exchange_mode aggressive,main;
#  	doi ipsec_doi;
#  	situation identity_only;

#         my_identifier address;

#         lifetime time 2 min;   # sec,min,hour
#         initial_contact on;
#         proposal_check obey;	# obey, strict or claim

#         proposal {
#                 encryption_algorithm 3des;
#                 hash_algorithm sha1;
#                 authentication_method pre_shared_key;
#                 dh_group 2 ;
#         }
# }
 
# sainfo anonymous
# {
#  	pfs_group 1;
#  	lifetime time 2 min;
#  	encryption_algorithm 3des ;
#  	authentication_algorithm hmac_sha1;
#         compression_algorithm deflate ;
# }


set -e

case $1 in
1)
setkey -c << EOF
	flush;
	spdflush;
 	# Add security policy (SP): everthing going *out* to DST must go over IPSEC and requires both ESP and AH
	spdadd $SRCIP $DSTIP any -P out ipsec	esp/transport//require;
 	# Add security policy (SP): any traffic coming *in* from DST is required to have valid ESP and AH. 
	spdadd $DSTIP $SRCIP any -P in ipsec	esp/transport//require;
EOF 
	;;
2)
setkey -c << EOF
	flush;
	spdflush;
	# Add security policy (SP): everthing going *out* to SRC must go over IPSEC and requires both ESP and AH
	spdadd $DSTIP $SRCIP any -P out ipsec esp/transport//require;
	# Add security policy (SP): any traffic coming *in* from SRC is required to have valid ESP and AH. 
	spdadd $SRCIP $DSTIP any -P in ipsec esp/transport//require;
EOF
	;;


*)
	echo Usage: ./ipsec_simple.sh hostid source_ip destination_ip 
    ;;
esac

echo "Done"