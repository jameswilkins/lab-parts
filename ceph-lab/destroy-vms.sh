#!/usr/bin/env bash

## Config

# Update this to point to where you checked out the git repository

GIT_DIR=/home/james/sites/lab-parts/ceph-lab

# Update this if you want your libvirt images storing somewhere else

LIBVIRT_DIR=/var/lib/libvirt/images

# Path to RHEL8.2 qcow2

RHEL82_PATH=/var/lib/libvirt/images/rhel-8.2-x86_64-kvm.qcow2

# Bail if a cmd fails

set -o errexit

# Bail on unset vars

set -o nounset

# Debugging

set -o xtrace

## Define libvirt network


virsh destroy ceph-bastion
virsh undefine ceph-bastion


for i in {01..03};
do
  virsh destroy ceph-$i
  virsh undefine ceph-$i
done


virsh net-destroy ceph-lab
virsh net-undefine ceph-lab

# Danger Danger - be wary of forced deletes in scripts

rm -i -f $LIBVIRT_DIR/ceph-*

