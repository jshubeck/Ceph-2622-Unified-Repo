#!/bin/bash

uid=$(grep -m 1 'ceph-node' /etc/hosts | awk '{print $2}' | sed 's/.*-\(.*\)/\1/')

yaml_file="/root/ceph-cluster-hosts.yaml"

yum install ansible -y

# Create the YAML configuration file with static entries and UID placeholders
cat <<EOF > "$yaml_file"
service_type: host
addr: ceph-node1-$uid
hostname: ceph-node1-$uid
labels:
  - mon
  - osd
  - rgw
  - mds
---

service_type: host
addr: ceph-node2-$uid
hostname: ceph-node2-$uid
labels:
  - mon
  - osd
  - rgw
  - mds
---

service_type: host
addr: ceph-node3-$uid
hostname: ceph-node3-$uid
labels:
  - mon
  - osd
  - nvmeof
---

service_type: host
addr: ceph-node4-$uid
hostname: ceph-node4-$uid
labels:
  - mon
  - osd
  - nfs
---
service_type: mds
service_id: cephfs
placement:
  label: "mds"
---
service_type: osd
service_id: all-available-devices
service_name: osd.all-available-devices
spec:
  data_devices:
    all: true
placement:
  label: "osd"
---
service_type: rgw
service_id: objectgw
service_name: rgw.objectgw
placement:
  count: 1
  label: "rgw"
spec:
  rgw_frontend_port: 8080

EOF

# Apply the configuration using cephadm
echo "Adding all hosts to the Ceph cluster..."
ceph orch apply -i "$yaml_file"

ceph config set global mon_max_pg_per_osd 512
# Create and enable a new RDB block pool.
ceph osd pool create rbdpool 32 32
ceph osd pool application enable rbdpool rbd

# Create the CephFS volume.
ceph fs volume create cephfs

echo "All Ceph nodes have been added to the cluster using $yaml_file. It will take around 5 minutes for the nodes to be added and the cluster in health+ok status"
