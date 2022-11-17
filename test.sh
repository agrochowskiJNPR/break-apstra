#!/bin/bash




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
        1)  read -s -p "Password: " password ;;
	2) ;; # some action on 2
	3)  ;;
	4) dialog --infobox "password is $password" 10 20; sleep 4 ;;
        *) ;; # some action on other
    esac
done
#clear # clear after user pressed Cancel
