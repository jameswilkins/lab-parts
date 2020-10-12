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

virsh net-define $GIT_DIR/network/ceph-lab.xml
virsh net-start ceph-lab
virsh net-autostart ceph-lab

## Bastion

qemu-img create -f qcow2 $LIBVIRT_DIR/ceph-bastion.qcow2 60G
virt-resize --expand /dev/sda3 $RHEL82_PATH $LIBVIRT_DIR/ceph-bastion.qcow2
virt-customize -a $LIBVIRT_DIR/ceph-bastion.qcow2 \
  --root-password password:password \
  --uninstall cloud-init \
  --hostname ceph-bastion.ceph.lab \
  --copy-in $GIT_DIR/config/hosts:/etc/ \
  --copy-in $GIT_DIR/config/ceph-bastion/ifcfg-eth0:/etc/sysconfig/network-scripts/ \
  --ssh-inject root:file:/root/.ssh/id_rsa.pub \
  --selinux-relabel
virt-install --name ceph-bastion \
  --virt-type kvm --memory 2048 --vcpus 2 \
  --boot hd,menu=on \
  --disk path=/var/lib/libvirt/images/ceph-bastion.qcow2,device=disk,bus=scsi,discard='unmap' \
  --graphics none \
  --os-type Linux --os-variant rhel8.2 \
  --network network:ceph-lab \
  --noautoconsole \
  --dry-run --print-xml >ceph-bastion.xml
virsh define ./ceph-bastion.xml
virsh start ceph-bastion

## Ceph Nodes

for i in {01,02,03}; 
do
  qemu-img create -f qcow2 /var/lib/libvirt/images/ceph-$i.qcow2 60G
  qemu-img create -f qcow2 /var/lib/libvirt/images/ceph-$i-diska.qcow2 10G
  qemu-img create -f qcow2 /var/lib/libvirt/images/ceph-$i-diskb.qcow2 10G
  virt-resize --expand /dev/sda3 /var/lib/libvirt/images/rhel-8.2-x86_64-kvm.qcow2 /var/lib/libvirt/images/ceph-$i.qcow2
  virt-customize -a /var/lib/libvirt/images/ceph-$i.qcow2 \
  --root-password password:password \
  --uninstall cloud-init \
  --hostname ceph-$i.ceph.lab \
  --copy-in $GIT_DIR/config/hosts:/etc/ \
  --copy-in $GIT_DIR/config/ceph-$i/ifcfg-eth0:/etc/sysconfig/network-scripts/ \
  --ssh-inject root:file:/root/.ssh/id_rsa.pub \
  --selinux-relabel
  virt-install --name ceph-$i \
  --virt-type kvm --memory 4096 --vcpus 2 \
  --boot hd,menu=on \
  --disk path=/var/lib/libvirt/images/ceph-$i.qcow2,device=disk,bus=scsi,discard='unmap' \
  --disk path=/var/lib/libvirt/images/ceph-$i-diska.qcow2,bus=scsi,discard='unmap' \
  --disk path=/var/lib/libvirt/images/ceph-$i-diskb.qcow2,bus=scsi,discard='unmap' \
  --graphics none \
  --os-type Linux --os-variant rhel8.2 \
  --network network:ceph-lab \
  --noautoconsole \
  --dry-run --print-xml >ceph-$i.xml
  virsh define ./ceph-$i.xml
  virsh start ceph-$i
done
