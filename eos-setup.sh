#!/bin/bash

# set up environment variables and other things
echo "setting environment variables"

export PATH=$PATH:/sbin
source /etc/sysconfig/eos
source /cf.env

echo "creating eos directories"
mkdir -p ${XRD_COREDIR}/core ${XRD_LOGDIR} ${EOS_DIR} ${EOS_DIR}/config/`hostname -f`
touch ${EOS_DIR}/eos.mq.master
touch ${EOS_DIR}/eos.mgm.rw
touch ${EOS_DIR}/config/`hostname -f`/default.eoscf

chown -R daemon:daemon ${XRD_COREDIR} ${XRD_LOGDIR} ${EOS_DIR}
chown daemon:daemon /etc/eos.keytab
cp /usr/local/lib64/libXrd* /usr/lib64/
cp /usr/local/bin/xrd* /usr/bin/

env | grep 'EOS\|XRD'
sleep 5

# start mq
cd ${XRD_COREDIR}/core
echo "starting mq.."
/usr/local/bin/xrootd -R daemon -n mq -c /etc/xrd.cf.mq -l /var/log/eos/xrdlog.mq -b -Iv4
echo "done!"

# start sync & mgm
echo "starting mgm & sync.."
/usr/local/bin/xrootd -R daemon -n sync -c /etc/xrd.cf.sync -l /var/log/eos/xrdlog.sync -b -Iv4
/usr/local/bin/xrootd -R daemon -n mgm -c /etc/xrd.cf.mgm -m -l /var/log/eos/xrdlog.mgm -b -Iv4
echo "done!"

# start fst
for i in {1..5}
do
    echo "starting fst ${i}.."
    cp /xrd.cf.fst.tmp /etc/xrd.cf.fst${i}
    echo "xrd.port $((2000+$i))" >> /etc/xrd.cf.fst${i}
    /usr/local/bin/xrootd -R daemon -n fst${i} -c /etc/xrd.cf.fst${i} -l /var/log/eos/xrdlog.fst${i} -b -Iv4
    mkdir -p /disks/eosfst${i}
    echo eosfst${i} > /disks/eosfst${i}/.eosfsuuid
    echo ${i} > /disks/eosfst${i}/.eosfsid
    chown -R daemon:daemon /disks/eosfst${i}
    eos -b fs add -m ${i} eosfst${i} `hostname -f`:$((2000+$i)) /disks/eosfst${i} default rw
    eos -b node set `hostname -f`:$((2000+$i)) on
done
echo "done!"

eos -b space set default on
eos -b vid enable sss
eos -b vid enable unix
eos -b fs boot \*
eos -b debug crit *
