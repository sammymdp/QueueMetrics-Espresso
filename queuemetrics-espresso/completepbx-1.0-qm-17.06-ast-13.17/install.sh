#! /bin/bash

# ---
# CompletePBX 1.0
#
# ---

# libreria di appoggio

echo "CompletePBX !";


. ../installLib.sh

QUEUEMETRICS="/usr/local/queuemetrics/tomcat/webapps/queuemetrics"
FILESQL="$QUEUEMETRICS/WEB-INF/README/queuemetrics_sample.sql"
CPROPSQM="$QUEUEMETRICS/WEB-INF/configuration.properties"
FILEAST="extensions_queuemetrics_CPBX.conf"
FILECPBX="/etc/asterisk/ombutel/extensions__60-queuemetrics.conf"

ROOTPASSWD=

# Gestione AMI
FILEAMI="/etc/asterisk/ombutel/manager__60-qm.conf"
AMIPASSWD=`< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-15};echo;`
echo "" > $FILEAMI
echo "[qmmanager] ; generated by QM Espresso" >> $FILEAMI
echo "secret = $AMIPASSWD" >> $FILEAMI
echo "deny = 0.0.0.0/0.0.0.0" >> $FILEAMI
echo "permit= 127.0.0.1/255.255.255.0" >> $FILEAMI
echo "read = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate" >> $FILEAMI
echo "write = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate" >> $FILEAMI
echo "writetimeout = 5000" >> $FILEAMI


PWD=`pwd`

echo "Complete PBX - Installing $0 from $PWD";
echo "File: $FILESQL"

/etc/init.d/uniloader stop
/etc/init.d/queuemetrics stop

echo "" | mysql -uqueuemetrics -pjavadude queuemetrics

if [ $? -ge 1 ]; then

echo "Creating database"

mysql -uroot mysql <<"EOF"
  CREATE DATABASE IF NOT EXISTS queuemetrics;
  GRANT ALL PRIVILEGES ON queuemetrics.* TO 'queuemetrics'@'localhost' IDENTIFIED BY  'javadude';
EOF

mysql -uqueuemetrics -pjavadude queuemetrics < $FILESQL

fi

echo CompletePBX config


cp $FILEAST $FILECPBX

rext $FILEELA 11 7 'ChanSpy(${QM_AGENT_LOGEXT})'
rext $FILEELA 14 6 'ChanSpy(${QM_AGENT_LOGEXT})'

asterisk -rx "core reload"


echo QM config

rv $CPROPSQM callfile.dir tcp:qmmanager:${AMIPASSWD}@127.0.0.1

rv $CPROPSQM default.queue_log_file sql:P001
rv $CPROPSQM realtime.max_bytes_agent 65000
rv $CPROPSQM realtime.agent_button_1.enabled false
rv $CPROPSQM realtime.agent_button_2.enabled false
rv $CPROPSQM realtime.agent_button_3.enabled false
rv $CPROPSQM realtime.agent_button_4.enabled false

rv $CPROPSQM default.monitored_calls /var/spool/asterisk/monitor/
rv $CPROPSQM layout.logo https://www.loway.ch/img/customlogos/completepbx-logo.png

rv $CPROPSQM realtime.members_only false
rv $CPROPSQM realtime.refresh_time 10
rv $CPROPSQM callfile.agentlogin.enabled false
rv $CPROPSQM callfile.agentlogoff.enabled false
rv $CPROPSQM callfile.transfercall.enabled true

rv $CPROPSQM default.rewriteLocalChannels true

rv $CPROPSQM default.hotdesking 86400
rv $CPROPSQM default.alwaysLogonUnpaused true
#rv $CPROPSQM default.autoconf.realtimeuri -

rv $CPROPSQM cluster.servers completepbx

rv $CPROPSQM default.crmapp "http://www.queuemetrics.com/sample_screen_pop.jsp?agent=[A]\&unique=[U]"

add $CPROPSQM cluster.completepbx.manager tcp:qmmanager:${AMIPASSWD}@127.0.0.1
add $CPROPSQM cluster.completepbx.queuelog sql:P001
add $CPROPSQM cluster.completepbx.monitored_calls /var/spool/asterisk/monitor/
add $CPROPSQM cluster.completepbx.callfile.dir tcp:qmmanager:${AMIPASSWD}@127.0.0.1

add $CPROPSQM realtime.useActivePolling true
add $CPROPSQM realtime.ajaxPollingDelay 5
add $CPROPSQM realtime.useRowCache true
add $CPROPSQM realtime.agent_autoopenurl true

# cos-all sostituisce from-internal
rv $CPROPSQM realtime.agent_button_4.channel "Local/104@cos-all"
rv $CPROPSQM callfile.monitoring.channel "Local/\$EM@cos-all/n"
rv $CPROPSQM callfile.outmonitoring.channel "Local/\$EM@cos-all/n"
rv $CPROPSQM callfile.customdial.channel "Local/\$EM@cos-all/n"

# Enabling DirectAMI 
rv $CPROPSQM platform.directami.transfer "\${num}@cos-all"

sleep 5
killall -9  /usr/local/queuemetrics/java/bin/java

/etc/init.d/uniloader start
/etc/init.d/queuemetrics start

allOK

