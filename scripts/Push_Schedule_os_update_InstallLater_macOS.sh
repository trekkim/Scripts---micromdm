#!/bin/bash
# The URL and API Key of the MicroMDM Server

#pat to your env file
export MICROMDM_ENV_PATH="$(pwd)/env"


#your micromdm secrets
hostname='https://yourMDM.com'
apiKey="yoursupersecret"

#specific variables
version="12.5.1"
deferrals="0"          #NUM set NUM as MaxUserDeferrals parameter of the UpdatesItem record
priority="High"        #Low, High
action="InstallLater"  #Default, DownloadOnly, InstallASAP, NotifyOnly, InstallLater, InstallForceRestart
serial="$1"

# reading each line
#path to your DEP-Profile.json or any other json with Serial Numbers
json='/path/to/DEP-Profile.json'
cat $json | jq -r '.devices[]' | while read line; do
echo "Pushing to : $line"


# Function to get the udid of a device from a serial
function getUdidForSerial {
    endpoint="v1/devices"
    serverURL="$2"
    apiKey="$3"
    response=$(jq -n \
      --arg filter_serial "$1" \
      '.filter_serial = '"["'$filter_serial'"]"'
      '|\
      curl -s -H "Content-Type: application/json" -u "micromdm:$apiKey" "$serverURL/$endpoint" -d@-\
    )
    echo $response | jq .devices[0].udid | sed 's/"//g'
}

# Function to Schedule
function schedule_os_update {
source $MICROMDM_ENV_PATH
endpoint="v1/commands"

jq -n \
  --arg request_type "ScheduleOSUpdate" \
  --arg udid "$udid" \
  --arg product_key "$key" \
  --arg product_version "$version" \
  --arg install_action "$action" \
  --arg priority "$priority" \
  --argjson max_user_deferrals "${deferrals--1}" \
  --arg command_uuid "$uuid" \
  '.udid = $udid
     | if $command_uuid != "" then .command_uuid = $command_uuid else . end
     | .request_type = $request_type
     | .updates = [
      .install_action = $install_action
      | if $max_user_deferrals != -1 then .max_user_deferrals = $max_user_deferrals else . end
      | if $product_key != "" then .product_key = $product_key else . end
      | if $product_version != "" then .product_version = $product_version else . end
      | if $priority != "" then .priority = $priority else . end
     ]
  '|\
  curl $CURL_OPTS -K <(cat <<< "-u micromdm:$API_TOKEN") "$SERVER_URL/$endpoint" -d@-

}



    udid=$(getUdidForSerial $line $hostname $apiKey)
    if [ "$udid" != "null" ]; then
        # Send the schedule_os_update command
        schedule_os_update $udid $action $version $deferrals
fi
done 