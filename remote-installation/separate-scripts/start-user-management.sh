#!/usr/bin/env bash
set -e

VERSION=2.0.1
TAG=$VERSION

read -p "Enter the Therapeutic Area of choice. Enter honeur/phederation/esfurn/athena [honeur]: " HONEUR_THERAPEUTIC_AREA
while [[ "$HONEUR_THERAPEUTIC_AREA" != "honeur" && "$HONEUR_THERAPEUTIC_AREA" != "phederation" && "$HONEUR_THERAPEUTIC_AREA" != "esfurn" && "$HONEUR_THERAPEUTIC_AREA" != "athena" && "$HONEUR_THERAPEUTIC_AREA" != "" ]]; do
    echo "Enter \"honeur\", \"phederation\", \"esfurn\", \"athena\" or empty for default \"honeur\" value"
    read -p "Enter the Therapeutic Area of choice. Enter honeur/phederation/esfurn/athena [honeur]: " HONEUR_THERAPEUTIC_AREA
done
HONEUR_THERAPEUTIC_AREA=${HONEUR_THERAPEUTIC_AREA:-honeur}

if [ "$HONEUR_THERAPEUTIC_AREA" = "honeur" ]; then
    HONEUR_THERAPEUTIC_AREA_DOMAIN=honeur.org
    HONEUR_THERAPEUTIC_AREA_URL=harbor-uat.$HONEUR_THERAPEUTIC_AREA_DOMAIN
    HONEUR_CHANGE_THERAPEUTIC_AREA_LIGHT_THEME_COLOR=\#0794e0
    HONEUR_CHANGE_THERAPEUTIC_AREA_DARK_THEME_COLOR=\#002562
elif [ "$HONEUR_THERAPEUTIC_AREA" = "phederation" ]; then
    HONEUR_THERAPEUTIC_AREA_DOMAIN=phederation.org
    HONEUR_THERAPEUTIC_AREA_URL=harbor-uat.$HONEUR_THERAPEUTIC_AREA_DOMAIN
    HONEUR_CHANGE_THERAPEUTIC_AREA_LIGHT_THEME_COLOR=\#3590d5
    HONEUR_CHANGE_THERAPEUTIC_AREA_DARK_THEME_COLOR=\#0741ad
elif [ "$HONEUR_THERAPEUTIC_AREA" = "esfurn" ]; then
    HONEUR_THERAPEUTIC_AREA_DOMAIN=esfurn.org
    HONEUR_THERAPEUTIC_AREA_URL=harbor-uat.$HONEUR_THERAPEUTIC_AREA_DOMAIN
    HONEUR_CHANGE_THERAPEUTIC_AREA_LIGHT_THEME_COLOR=\#668772
    HONEUR_CHANGE_THERAPEUTIC_AREA_DARK_THEME_COLOR=\#44594c
elif [ "$HONEUR_THERAPEUTIC_AREA" = "athena" ]; then
    HONEUR_THERAPEUTIC_AREA_DOMAIN=athenafederation.org
    HONEUR_THERAPEUTIC_AREA_URL=harbor-uat.$HONEUR_THERAPEUTIC_AREA_DOMAIN
    HONEUR_CHANGE_THERAPEUTIC_AREA_LIGHT_THEME_COLOR=\#0794e0
    HONEUR_CHANGE_THERAPEUTIC_AREA_DARK_THEME_COLOR=\#002562
fi

read -p "Enter email address used to login to https://portal-uat.$HONEUR_THERAPEUTIC_AREA_DOMAIN: " HONEUR_EMAIL_ADDRESS
while [[ "$HONEUR_EMAIL_ADDRESS" == "" ]]; do
    echo "Email address can not be empty"
    read -p "Enter email address used to login to https://portal-uat.$HONEUR_THERAPEUTIC_AREA_DOMAIN: " HONEUR_EMAIL_ADDRESS
done
echo "Surf to https://$HONEUR_THERAPEUTIC_AREA_URL and login using the button \"LOGIN VIA OIDC PROVIDER\". Then click your account name on the top right corner of the screen and click \"User Profile\". Copy the CLI secret by clicking the copy symbol next to the text field."
read -p 'Enter the CLI Secret: ' HONEUR_CLI_SECRET
while [[ "$HONEUR_CLI_SECRET" == "" ]]; do
    echo "CLI Secret can not be empty"
    read -p "Enter the CLI Secret: " HONEUR_CLI_SECRET
done

read -p "User Management administrator username [admin]: " HONEUR_USERMGMT_ADMIN_USERNAME
HONEUR_USERMGMT_ADMIN_USERNAME=${HONEUR_USERMGMT_ADMIN_USERNAME:-admin}
read -p "User Management administrator password [admin]: " HONEUR_USERMGMT_ADMIN_PASSWORD
HONEUR_USERMGMT_ADMIN_PASSWORD=${HONEUR_USERMGMT_ADMIN_PASSWORD:-admin}

touch user-mgmt.env

echo "HONEUR_THERAPEUTIC_AREA_NAME=$HONEUR_THERAPEUTIC_AREA" >> user-mgmt.env
echo "HONEUR_THERAPEUTIC_AREA_LIGHT_THEME_COLOR=$HONEUR_CHANGE_THERAPEUTIC_AREA_LIGHT_THEME_COLOR" >> user-mgmt.env
echo "HONEUR_THERAPEUTIC_AREA_DARK_THEME_COLOR=$HONEUR_CHANGE_THERAPEUTIC_AREA_DARK_THEME_COLOR" >> user-mgmt.env
echo "HONEUR_USERMGMT_USERNAME=$HONEUR_USERMGMT_ADMIN_USERNAME" >> user-mgmt.env
echo "HONEUR_USERMGMT_PASSWORD=$HONEUR_USERMGMT_ADMIN_PASSWORD" >> user-mgmt.env
echo "DATASOURCE_DRIVER_CLASS_NAME=org.postgresql.Driver" >> user-mgmt.env
echo "DATASOURCE_URL=jdbc:postgresql://postgres:5432/OHDSI?currentSchema=webapi" >> user-mgmt.env
echo "WEBAPI_ADMIN_USERNAME=ohdsi_admin_user" >> user-mgmt.env

echo "Stop and remove user-mgmt container if exists"
docker stop user-mgmt > /dev/null 2>&1 || true
docker rm user-mgmt > /dev/null 2>&1 || true

echo "Create $HONEUR_THERAPEUTIC_AREA-net network if it does not exists"
docker network create --driver bridge $HONEUR_THERAPEUTIC_AREA-net > /dev/null 2>&1 || true

echo "Pull $HONEUR_THERAPEUTIC_AREA/user-mgmt:$TAG from https://$HONEUR_THERAPEUTIC_AREA_URL. This could take a while if not present on machine"
echo "$HONEUR_CLI_SECRET" | docker login https://$HONEUR_THERAPEUTIC_AREA_URL --username $HONEUR_EMAIL_ADDRESS --password-stdin
docker pull $HONEUR_THERAPEUTIC_AREA_URL/$HONEUR_THERAPEUTIC_AREA/user-mgmt:$TAG

echo "Run $HONEUR_THERAPEUTIC_AREA/user-mgmt:$TAG container. This could take a while..."
docker run \
--name "user-mgmt" \
--restart on-failure:5 \
--security-opt no-new-privileges \
--env-file user-mgmt.env \
-v "shared:/var/lib/shared:ro" \
-m "800m" \
--cpus "1" \
--pids-limit 100 \
--cpu-shares 1024 \
--ulimit nofile=1024:1024 \
-d \
$HONEUR_THERAPEUTIC_AREA_URL/$HONEUR_THERAPEUTIC_AREA/user-mgmt:$TAG > /dev/null 2>&1

echo "Connect user-mgmt to $HONEUR_THERAPEUTIC_AREA-net network"
docker network connect $HONEUR_THERAPEUTIC_AREA-net user-mgmt > /dev/null 2>&1

echo "Clean up helper files"
rm -rf user-mgmt.env

echo "Done"