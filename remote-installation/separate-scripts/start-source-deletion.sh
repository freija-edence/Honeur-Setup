#!/usr/bin/env bash
set -e

cr=$(echo $'\n.')
cr=${cr%.}

VERSION=2.0.0
TAG=webapi-source-delete-$VERSION

read -p 'Enter the Therapeutic Area of choice. Enter honeur/phederation/esfurn/athena [honeur]: ' FEDER8_THERAPEUTIC_AREA
while [[ "$FEDER8_THERAPEUTIC_AREA" != "honeur" && "$FEDER8_THERAPEUTIC_AREA" != "phederation" && "$FEDER8_THERAPEUTIC_AREA" != "esfurn" && "$FEDER8_THERAPEUTIC_AREA" != "athena" && "$FEDER8_THERAPEUTIC_AREA" != "" ]]; do
    echo "Enter \"honeur\", \"phederation\", \"esfurn\", \"athena\" or empty for default \"honeur\" value"
    read -p "Enter the Therapeutic Area of choice. Enter honeur/phederation/esfurn/athena [honeur]: " FEDER8_THERAPEUTIC_AREA
done
FEDER8_THERAPEUTIC_AREA=${FEDER8_THERAPEUTIC_AREA:-honeur}

if [ "$FEDER8_THERAPEUTIC_AREA" = "honeur" ]; then
    FEDER8_THERAPEUTIC_AREA_DOMAIN=honeur.org
    FEDER8_THERAPEUTIC_AREA_URL=harbor.$FEDER8_THERAPEUTIC_AREA_DOMAIN
elif [ "$FEDER8_THERAPEUTIC_AREA" = "phederation" ]; then
    FEDER8_THERAPEUTIC_AREA_DOMAIN=phederation.org
    FEDER8_THERAPEUTIC_AREA_URL=harbor.$FEDER8_THERAPEUTIC_AREA_DOMAIN
elif [ "$FEDER8_THERAPEUTIC_AREA" = "esfurn" ]; then
    FEDER8_THERAPEUTIC_AREA_DOMAIN=esfurn.org
    FEDER8_THERAPEUTIC_AREA_URL=harbor.$FEDER8_THERAPEUTIC_AREA_DOMAIN
elif [ "$FEDER8_THERAPEUTIC_AREA" = "athena" ]; then
    FEDER8_THERAPEUTIC_AREA_DOMAIN=athenafederation.org
    FEDER8_THERAPEUTIC_AREA_URL=harbor.$FEDER8_THERAPEUTIC_AREA_DOMAIN
fi

read -p "Enter email address used to login to https://portal.$FEDER8_THERAPEUTIC_AREA_DOMAIN: " FEDER8_EMAIL_ADDRESS
while [[ "$FEDER8_EMAIL_ADDRESS" == "" ]]; do
    echo "Email address can not be empty"
    read -p "Enter email address used to login to https://portal.$FEDER8_THERAPEUTIC_AREA_DOMAIN: " FEDER8_EMAIL_ADDRESS
done
read -p "Surf to https://$FEDER8_THERAPEUTIC_AREA_URL and login using the button \"LOGIN VIA OIDC PROVIDER\". Then click your account name on the top right corner of the screen and click \"User Profile\". Copy the CLI secret by clicking the copy symbol next to the text field.${cr}Enter the CLI Secret: " FEDER8_CLI_SECRET
while [[ "$FEDER8_CLI_SECRET" == "" ]]; do
    echo "CLI Secret can not be empty"
    read -p "Enter the CLI Secret: " FEDER8_CLI_SECRET
done

read -p 'Enter the database host [postgres]: ' FEDER8_DATABASE_HOST
FEDER8_DATABASE_HOST=${FEDER8_DATABASE_HOST:-postgres}

read -p 'Enter the name of the source to delete [HONEUR OMOP CDM]: ' FEDER8_SOURCE_NAME
FEDER8_SOURCE_NAME=${FEDER8_SOURCE_NAME:-HONEUR OMOP CDM}

if [ -z "$FEDER8_SHARED_SECRETS_VOLUME_NAME" ]; then
    echo "FEDER8_SHARED_SECRETS_VOLUME_NAME not set, using default shared volume for secrets."
    FEDER8_SHARED_SECRETS_VOLUME_NAME=shared
fi

touch webapi-source-delete.env

echo "DB_HOST=${FEDER8_DATABASE_HOST}" >> webapi-source-delete.env
echo "FEDER8_SOURCE_NAME=${FEDER8_SOURCE_NAME} QA" >> webapi-source-delete.env

echo "Stop and remove $FEDER8_POSTGRES_CONTAINER_NAME container if exists"
docker stop webapi-source-delete > /dev/null 2>&1 || true
docker rm webapi-source-delete > /dev/null 2>&1 || true

echo "Create $FEDER8_THERAPEUTIC_AREA-net network if it does not exists"
docker network create --driver bridge $FEDER8_THERAPEUTIC_AREA-net > /dev/null 2>&1 || true

echo "Pull $FEDER8_THERAPEUTIC_AREA/postgres:$TAG from https://$FEDER8_THERAPEUTIC_AREA_URL. This could take a while if not present on machine..."
echo "$FEDER8_CLI_SECRET" | docker login https://$FEDER8_THERAPEUTIC_AREA_URL --username $FEDER8_EMAIL_ADDRESS --password-stdin
docker pull $FEDER8_THERAPEUTIC_AREA_URL/$FEDER8_THERAPEUTIC_AREA/postgres:$TAG

echo "Run $FEDER8_THERAPEUTIC_AREA/postgres:$TAG container. This could take a while..."
docker run \
--name "webapi-source-delete" \
--rm \
-v $FEDER8_SHARED_SECRETS_VOLUME_NAME:/var/lib/shared \
--env-file webapi-source-delete.env \
--network $FEDER8_THERAPEUTIC_AREA-net \
$FEDER8_THERAPEUTIC_AREA_URL/$FEDER8_THERAPEUTIC_AREA/postgres:$TAG > /dev/null 2>&1

echo "Clean up helper files"
rm -rf webapi-source-delete.env

echo "Done"
