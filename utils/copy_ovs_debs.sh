#!/bin/bash

# utils/copy_ovs_debs.sh ~/openvswitch-2.4.0 2.4.0-1 etcd-01 ;  utils/copy_ovs_debs.sh ~/openvswitch-2.4.0 2.4.0-1 etcd-02 ; utils/copy_ovs_debs.sh ~/openvswitch-2.4.0 2.4.0-1 etcd-03

DIR_PATH=$1
VERSION=$2
REMOTE=$3

vagrant scp $DIR_PATH/openvswitch-common_"$VERSION"_amd64.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/openvswitch-datapath-dkms_"$VERSION"_all.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/openvswitch-datapath-source_"$VERSION"_all.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/openvswitch-dbg_"$VERSION"_amd64.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/openvswitch-ipsec_"$VERSION"_amd64.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/openvswitch-pki_"$VERSION"_all.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/openvswitch-switch_"$VERSION"_amd64.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/openvswitch-test_"$VERSION"_all.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/openvswitch-vtep_"$VERSION"_amd64.deb $REMOTE:/tmp
vagrant scp $DIR_PATH/python-openvswitch_"$VERSION"_all.deb $REMOTE:/tmp
