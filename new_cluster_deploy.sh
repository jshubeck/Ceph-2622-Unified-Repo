cd /usr/share/cephadm-ansible/
ansible-playbook -i /usr/share/cephadm-ansible/hosts cephadm-preflight.yml --extra-vars "ceph_origin=ibm" --limit '!client'
ip=$(getent hosts "ceph-node1" | awk '{ print $1 }')
cephadm \
	bootstrap \
	--registry-json /root/scripts/registry.json \
	--dashboard-password-noupdate \
	--ssh-user=root \
	--mon-ip ${ip} \
	--apply-spec /root/scripts/ceph-cluster-hosts.yaml
