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

getswitchinfo() {
declare -A switches `curl --location --request POST "https://$apstraserver/api/blueprints/$bpid/qe?type=staging" \
--header "AUTHTOKEN: eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwiY3JlYXRlZF9hdCI6IjIwMjItMTItMDhUMTU6MjA6MzguMDAyMDQ4IiwidXNlcl9zZXNzaW9uIjoiYTIwNDBlOWYtZDg0NS00NzA4LTg0MmItZWY0NWNkMDdhOGY1IiwiZXhwIjoxNjcwNTk5MjM4fQ.VDkTJq1_8GaXS8xIvn1Mr61pOtJInAQDMJkwnOvHGHZ05tvsF88AFFXwhmAJoSbGFaQzuZ1rcOx1zrBMH3S2hQ" --header "Content-Type: application/json" --data-raw "{
  \"query\": \"match(node('system', name='system', role=is_in(['leaf', 'access', 'spine', 'superspine'])))\"}" | jq -r '.items[].system | .label + ": " + .system_id' | tr '\n' ' '`

echo ${switch[leaf3]}
sleep 5
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
sleep 2
}

disableint() {
read -s -p "Enter Spine1 IP:" spine1_ip
  sleep 4
 echo "spine1 ip is $spine1_ip"
( echo 'conf';echo 'set int xe-0/0/01 disable';echo 'commit and-quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$spine1_ip" "cli"
sleep 2
}
changeswasn() {
read -s -p "Enter IP of desired switch to mess up:" switch_ip
  sleep 4
 echo "entered switch ip is $switch_ip"
( echo 'conf';echo 'set routing-options autonomous-system 645135';echo 'commit and-quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
sleep 2
}
savetv() {
commitversion=`curl -k --location --request GET "https://$apstraserver/api/blueprints/$bpid/deploy" --header "AUTHTOKEN: $authtoken" | jq .version --raw-output`
echo "version is $commitversion"
sleep 1
curl -k --location --request POST "https://$apstraserver/api/blueprints/$bpid/revisions/$commitversion/keep" --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"description\": \"Saved by Apstra Chaos Cat at `date` \"}"
}
setstaticrt() {
( 
read -s -p "Enter IP of desired switch to add "routing-options static route 7.7.7.7/32 next-hop 8.8.8.8" to:" switch_ip
  sleep 1
 echo "entered switch ip is $switch_ip"
echo 'conf';echo 'set routing-options static route 7.7.7.7/32 next-hop 8.8.8.8' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$spine1_ip" "cli"
}
TITLE="How Would You Like to Break Your Environment Today?"
	
items=(1 "*nw Enter Apstra Password"
       2 "Change Blueprint Name"
       3 "Config Deviation Anomoly - Disable Interface"
       4 "Save Current Blueprint"
       5 "Break Cabling Map"
       6 "Change the ASN of a device"
       7 "Add a random static route to switch"
       )

while choice=$(dialog --title "$TITLE" \
                 --menu "Please select" 50 80 8 "${items[@]}" \
                 2>&1 >/dev/tty)
    do
    case $choice in
        1) password=`dialog --title "Password" --clear --passwordbox "Enter your password" 10 30 2`  ;; #read -s -p "Password: " password ;;
	2) get_bp_id; sleep 3 ;; # some action on 2
	3) disableint ;sleep 4 ;;
	4) savetv; sleep 1 ;;
	5) breakcablemap ; sleep 4 ;;
	6) changeswasn ; sleep 4 ;;
	7) setstaticrt ; sleep 2 ;;
        *) ;; # some action on other
    esac
done
#clear # clear after user pressed Cancel
