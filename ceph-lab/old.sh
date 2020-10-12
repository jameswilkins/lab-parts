#!/bin/bash
RHIMAGE="rhel-8.2-x86_64-kvm.qcow2"

#for node in {ceph-bastion,ceph-01,ceph-02,ceph03}; do

#Pre-create some files

TMP_DIR=$(mktemp -d -t ceph-lab-files-XXXXXXX)

cat > $TMP_DIR/hosts <<EOF
127.0.0.1  localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.16.200.10 ceph-bastion.ceph.lab ceph-bastion
172.16.200.20 ceph-01.ceph.lab ceph-01
172.16.200.21 ceph-02.ceph.lab ceph-02
172.16.200.22 ceph-03.ceph.lab ceph-03
EOF

mkdir $TMP_DIR/ceph-bastion


qemu-img create -f qcow2 test.qcow2 60G
virt-resize --expand /dev/sda3 ~james/sites/lab-parts/ceph-lab/rhel-8.2-x86_64-kvm.qcow2 ./test.qcow2
cloud-localds -v --network-config=network_config_static.cfg ceph-bastion-init.qcow2 cloud_init.cfg
virt-install --name test\
  --virt-type kvm --memory 2048 --vcpus 2 \
  --boot hd,menu=on \
  --disk path=ceph-bastion-init.qcow2,device=cdrom \
  --disk path=test.qcow2,device=disk \
  --graphics none \
  --noautoconsole \
  --os-type Linux --os-variant rhel8.2 \
  --network network:ceph-lab
cat > $TMP_DIR/ceph-bastion/ifcfg-eth0
for node in ceph-bastion; do
	echo "Configuring $node"
  cp $RHIMAGE /var/lib/libvirt/images/$node.qcow  
  virt-customise /var/lib/libvirt/images/$node.qcow \
    --root-password password:password \
    --uninstall cloud-init \
    --timezone "Europe\London" \
    --hostname $node.ceph.lab \
    --copy-in $TMP_DIR/hosts:/etc/ \
    --copy-in $TMP_DIR/$node/if-cfg-eth0:/etc/sysconfig/network-scripts/ \
    --selinux-relabel
done

rm -f $TMP_DIR/hosts
rmdir $TMP_DIR

