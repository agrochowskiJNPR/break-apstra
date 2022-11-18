#!/bin/bash


get_bp_id() {
authtoken=`curl -k --location --request POST 'https://10.28.207.3/api/user/login' --header 'Content-Type: application/json' --data-raw '{
  "username": "admin",
  "password": "admin"
}' | awk '{print $2}' | sed s/[\"\,]//g`
echo "authtoken is $authtoken"
bpid=`curl -k --location --request GET 'https://10.28.207.3/api/blueprints/' --header "AUTHTOKEN: $authtoken" |  /usr/bin/jq '.items[0] .id' --raw-output`
echo "blueprint id is $bpid"
read -s -p "New Blueprint Name:" newbpname
bp_node_id=`curl -k --location --request GET 'https://10.28.207.3/api/blueprints/'$bpid --header "AUTHTOKEN: $authtoken" |jq --raw-output '.nodes[] | select(.design =="two_stage_l3clos") | .id'`  #get node id
echo "\n node id is $bp_node_id"
curl -k --location --request PATCH "https://10.28.207.3/api/blueprints/$bpid" --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"nodes\": {\"$bp_node_id\" : { \"label\": \"$newbpname\"}}}"
}



TITLE="How Would You Like to Break Apstra Today?"
	
items=(1 "Enter Apstra Password"
       2 "Change Blueprint Name"
       3 "Commit a Change"
       4 "Config Deviation Anomoly"
       5 "VLAN ID Mismatch"
       6 "Imbalance Probes"
       7 "roll back everything"
       )

while choice=$(dialog --title "$TITLE" \
                 --menu "Please select" 50 80 8 "${items[@]}" \
                 2>&1 >/dev/tty)
    do
    case $choice in
        1) password=`dialog --title "Password" --clear --passwordbox "Enter your password" 10 30 2`  ;; #read -s -p "Password: " password ;;
	2) get_bp_id; sleep 3 ;; # some action on 2
	3) dialog --infobox "bp id is $bpid" 10 20 ;sleep 4 ;;
	4) dialog --infobox "password is $password" 10 20; sleep 4 ;;
        *) ;; # some action on other
    esac
done
#clear # clear after user pressed Cancel
