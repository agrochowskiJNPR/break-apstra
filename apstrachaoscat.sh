#!/bin/bash

apstraserver="127.0.0.1"
authtoken=`curl -k --location --request POST "https://$apstraserver/api/user/login" --header 'Content-Type: application/json' --data-raw '{
  "username": "admin",
  "password": "admin"
}' | awk '{print $2}' | sed s/[\"\,]//g`
echo "authtoken is $authtoken"
bpid=`curl -k --location --request GET "https://$apstraserver/api/blueprints/" --header "AUTHTOKEN: $authtoken" |  /usr/bin/jq '.items[0] .id' --raw-output`
echo "blueprint id is $bpid"

get_bp_id() { #change me to change bp id
authtoken=`curl -k --location --request POST "https://$apstraserver/api/user/login" --header 'Content-Type: application/json' --data-raw '{
  "username": "admin",
  "password": "admin"
}' | awk '{print $2}' | sed s/[\"\,]//g`
echo "authtoken is $authtoken"
bpid=`curl -k --location --request GET "https://$apstraserver/api/blueprints/" --header "AUTHTOKEN: $authtoken" |  /usr/bin/jq '.items[0] .id' --raw-output`
echo "blueprint id is $bpid"
read -s -p "New Blueprint Name:" newbpname
bp_node_id=`curl -k --location --request GET "https://$apstraserver/api/blueprints/$bpid" --header "AUTHTOKEN: $authtoken" |jq --raw-output '.nodes[] | select(.design =="two_stage_l3clos") | .id'`  #get node id
echo "\n node id is $bp_node_id"
curl -k --location --request PATCH "https://$apstraserver/api/blueprints/$bpid" --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"nodes\": {\"$bp_node_id\" : { \"label\": \"$newbpname\"}}}"
}

breakcablemap() {

endpoints=`curl -k --location --request GET "https://$apstraserver/api/blueprints/$bpid/experience/web/cabling-map" --header "AUTHTOKEN: $authtoken" --data-raw "" | jq '.links[] | select(.label == "spine1<->evpn_esi_001_leaf2[1]") | {endpoints}'`

intf1id=`echo $endpoints | jq --raw-output '.endpoints[0] .interface.id'`
intf2id=`echo $endpoints | jq --raw-output '.endpoints[1] .interface.id'`
echo $intf1id
echo $intf2id

curl -k --location --request PATCH "https://$apstraserver/api/blueprints/$bpid/cabling-map" \
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
sleep 14
}

disableint() {
 swip=`dialog --title "spine1 IP?" --clear --inputbox "Enter Spine1 IP" 10 30 2`
 echo "spine1 ip is $swip"
 sleep 3
( echo ‘conf’;echo ‘set int xe-0/0/01 disable’;echo ‘commit and-quit’ ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@$swip “cli”
sleep 3
}
TITLE="How Would You Like to Break Your Environment Today?"
	
items=(1 "*nw Enter Apstra Password"
       2 "Change Blueprint Name"
       3 "*nw Commit a Change"
       4 "Config Deviation Anomoly - Disable Interface"
       5 "Break Cabling Map"
       6 "*nw VLAN ID Mismatch"
       7 "*nw Imbalance Probes"
       8 "*nw roll back everything"
       )

while choice=$(dialog --title "$TITLE" \
                 --menu "Please select" 50 80 8 "${items[@]}" \
                 2>&1 >/dev/tty)
    do
    case $choice in
        1) password=`dialog --title "Password" --clear --passwordbox "Enter your password" 10 30 2`  ;; #read -s -p "Password: " password ;;
	2) get_bp_id; sleep 3 ;; # some action on 2
	3) disableint ;sleep 4 ;;
	4) dialog --infobox "password is $password" 10 20; sleep 4 ;;
	5) breakcablemap ; sleep 4 ;;
        *) ;; # some action on other
    esac
done
#clear # clear after user pressed Cancel
