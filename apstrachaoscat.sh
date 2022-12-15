#!/bin/bash

apstraserver="127.0.0.1"
apstrapass="admin"
authtoken=`curl -s -k --location --request POST "https://$apstraserver/api/user/login" --header 'Content-Type: application/json' --data-raw "{
  \"username\": \"admin\",
  \"password\": \"$apstrapass\"
}" | awk '{print $2}' | sed s/[\"\,]//g`
echo "authtoken is $authtoken"
bpid=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/" --header "AUTHTOKEN: $authtoken" |  /usr/bin/jq '.items[0] .id' --raw-output`
echo "blueprint id is $bpid"

get_bp_id() { #change me to change bp id
authtoken=`curl -s -k --location --request POST "https://$apstraserver/api/user/login" --header 'Content-Type: application/json' --data-raw "{
  \"username\": \"admin\",
  \"password\": \"$apstrapass\"
}" | awk '{print $2}' | sed s/[\"\,]//g`
echo "authtoken is $authtoken"
bpid=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/" --header "AUTHTOKEN: $authtoken" |  /usr/bin/jq '.items[0] .id' --raw-output`
echo "blueprint id is $bpid"
read -s -p "New Blueprint Name:" newbpname
bp_node_id=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/$bpid" --header "AUTHTOKEN: $authtoken" |jq --raw-output '.nodes[] | select(.design =="two_stage_l3clos") | .id'`  #get node id
echo "\n node id is $bp_node_id"
curl -s -k --location --request PATCH "https://$apstraserver/api/blueprints/$bpid" --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"nodes\": {\"$bp_node_id\" : { \"label\": \"$newbpname\"}}}"
}


getswitchinfo() {
declare -A switches `curl -s -k --location --request POST "https://$apstraserver/api/blueprints/$bpid/qe?type=staging" \
--header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"query\": \"match(node('system', name='system', role=is_in(['leaf', 'access', 'spine', 'superspine'])))\"}" | jq -r '.items[].system | "switches" + "[" + .label + "]" + "=" + .system_id' |tr '\n' ' '`

MENU_OPTIONS=
COUNT=0

PS3="Please enter your choice (q to quit): "
select target in "${!switches[@]}" "quit";
do
    case "$target" in
        "quit")
            echo "Exited"
            break
            ;;
        *)
            selected_systemid=${switches["$target"]}
            selected_switch="$target"
	    switch_ip=`curl -k --location --request GET "https://$apstraserver/api/systems/$selected_systemid" --header "AUTHTOKEN: $authtoken" --data-raw "" | jq -r '.facts .mgmt_ipaddr'`
            echo "$selected_switch system id is $selected_systemid and has IP $switch_ip"
	    break
	    ;;
    esac
done
}




breakcablemap() {

endpoints=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/$bpid/experience/web/cabling-map" --header "AUTHTOKEN: $authtoken" --data-raw "" | jq '.links[] | select(.label == "spine1<->evpn_esi_001_leaf2[1]") | {endpoints}'`

intf1id=`echo $endpoints | jq --raw-output '.endpoints[0] .interface.id'`
intf2id=`echo $endpoints | jq --raw-output '.endpoints[1] .interface.id'`
echo $intf1id
echo $intf2id

curl -s -k --location --request PATCH "https://$apstraserver/api/blueprints/$bpid/cabling-map" \
--header "AUTHTOKEN: $authtoken" \
--header "Content-Type: application/json" \
--data-raw " {
    \"links\": [
      {
        \"endpoints\": [
          {
            \"interface\": {
              \"id\": \"$intf1id\",
              \"if_name\": \"xe-0/0/5\"
            }
          },
          {
            \"interface\": {
              \"id\": \"$intf2id\"
            }
          }
        ],
        \"id\": \"spine1<->evpn_esi_001_leaf2[1]\"
      }
    ]
  }"
sleep 2
}

disableint() {
getswitchinfo
( echo 'conf';echo 'set int xe-0/0/01 disable';echo 'commit and-quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
sleep 2
}
changeswasn() {
getswitchinfo
( echo 'conf';echo 'set routing-options autonomous-system 645135';echo 'commit and-quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
sleep 2
}
savetv() {
commitversion=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/$bpid/deploy" --header "AUTHTOKEN: $authtoken" | jq .version --raw-output`
echo "version is $commitversion"
sleep 1
curl -s -k --location --request POST "https://$apstraserver/api/blueprints/$bpid/revisions/$commitversion/keep" --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"description\": \"Saved by Apstra Chaos Cat at `date` \"}"
}
commitcurrent()
{
commitversion=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/" --header "AUTHTOKEN: $authtoken" | jq '.items[] .version'  --raw-output`
echo "version is $commitversion"
#curl -s -k -v --location  --request PUT "https://$apstraserver/api/$bpid/deploy" --header "AUTHTOKEN: $authtoken" --header 'Content-Type: application/json' --data-raw '{ "description": "committed by Apstra Chaos Cat at `date`"}'
curl -k --location -g --request PUT "https://$apstraserver/api/blueprints/$bpid/deploy" \
--header "AUTHTOKEN: $authtoken" \
--header "Content-Type: application/json" \
--data-raw "{
    \"version\": "$commitversion",
    \"description\": \"Committed by script at `date`\"
}"
}

setstaticrt() {
( 
getswitchinfo
echo 'conf';echo 'set routing-options static route 7.7.7.7/32 next-hop 8.8.8.8' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
}
flapif() {
getswitchinfo
echo "NB: This is a pretty bad hack, and will continue rapidly flapping the interface until you hit Control-C.  Please also be advised that it might leave the IF in a down state when you do stop it. If that happens either reboot the switch, or login and kill flap.sh (ps aux | grep flap.sh, and kill the PID)"
 (echo 'echo "while true;do ifconfig xe-0/0/0 down;ifconfig xe-0/0/0 up; done"> flap.sh';echo 'sh ./flap.sh') | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@$switch_ip sh
}
rampcpu() {
getswitchinfo
echo "NB: This is a pretty bad hack, but should peg the cpu @100% on a vQFX. Hit ^C (Control-C) to stop the pain. Make certain that the Device System Health probe is enabled, and note also that it will take 6 minutes and 1 second to raise an anomaly"
sshpass -proot123 ssh -o StrictHostKeyChecking=no root@$switch_ip 'dd if=/dev/zero of=/dev/null'
}

rebootall() {
declare -A switches `curl -s -k --location --request POST "https://$apstraserver/api/blueprints/$bpid/qe?type=staging" --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"query\": \"match(node('system', name='system', role=is_in(['leaf', 'access', 'spine', 'superspine'])))\"}" | jq -r '.items[].system | "switches" + "[" + .label + "]" + "=" + .system_id' |tr '\n' ' '`

for dev in "${switches[@]}";
do
        switch_ip=`curl -k --location --request GET "https://$apstraserver/api/systems/$dev" --header "AUTHTOKEN: $authtoken" --data-raw "" | jq -r '.facts .mgmt_ipaddr'`;
        ( echo 'request system reboot'; echo 'yes'; echo 'quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
        echo $switch_ip
done
}



TITLE="How Would You Like to Break Your Environment Today?"
	
items=(1 "Change Blueprint Name"
       2 "Disable switch Interface (xe-0/0/0)"
       3 "Save Current Blueprint Version"
       4 "Break Cabling Map"
       5 "Change the ASN of a device"
       6 "Add a static route to a device"
       7 "List Switch IPs"
       8 "Flap xe-0/0/0 on selected device"
       9 "Ramp a device CPU to raise device Health anomaly"
       10 "Run a Commit"
       11 "reboot all junos devices under Apstra management"
       )

while choice=$(dialog --title "$TITLE" \
                 --menu "Please select" 50 80 12 "${items[@]}" \
                 2>&1 >/dev/tty)
    do
    case $choice in
	1) get_bp_id; sleep 3 ;; # some action on 2
	2) disableint ;sleep 4 ;;
	3) savetv; sleep 1 ;;
	4) breakcablemap ; sleep 4 ;;
	5) changeswasn ; sleep 4 ;;
	6) setstaticrt ; sleep 2 ;;
	7) getswitchinfo ;  ;;
	8) flapif ; sleep 2 ;;
	9) rampcpu ; ;; 
	10) commitcurrent ; sleep 5 ;;
	11) rebootall ; sleep 3 ;;
        *) ;; # some action on other
    esac
done
#clear # clear after user pressed Cancel
