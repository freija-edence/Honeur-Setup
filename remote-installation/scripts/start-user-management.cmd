@echo off

SET VERSION=2.0.0
SET TAG=%VERSION%

SET /p HONEUR_USERMGMT_ADMIN_USERNAME="usermgmt admin username [admin]: " || SET HONEUR_USERMGMT_ADMIN_USERNAME=admin
SET /p HONEUR_USERMGMT_ADMIN_PASSWORD="usermgmt admin password [admin]: " || SET HONEUR_USERMGMT_ADMIN_PASSWORD=admin

echo. 2>user-mgmt.env

echo HONEUR_USERMGMT_USERNAME=%HONEUR_USERMGMT_ADMIN_USERNAME%> user-mgmt.env
echo HONEUR_USERMGMT_PASSWORD=%HONEUR_USERMGMT_ADMIN_PASSWORD%>> user-mgmt.env
echo DATASOURCE_DRIVER_CLASS_NAME=org.postgresql.Driver>> user-mgmt.env
echo DATASOURCE_URL=jdbc:postgresql://postgres:5432/OHDSI?currentSchema=webapi>> user-mgmt.env
echo WEBAPI_ADMIN_USERNAME=ohdsi_admin_user>> user-mgmt.env

echo Stop and remove user-mgmt container if exists
docker stop user-mgmt >nul 2>&1
docker rm user-mgmt >nul 2>&1

echo Create honeur-net network if it does not exists
docker network create --driver bridge honeur-net >nul 2>&1

echo Pull honeur/user-mgmt:%TAG% from docker hub. This could take a while if not present on machine
docker pull honeur/user-mgmt:%TAG% >nul 2>&1

echo Run honeur/user-mgmt:%TAG% container. This could take a while...
docker run ^
--name "user-mgmt" ^
--restart always ^
--security-opt no-new-privileges ^
--env-file user-mgmt.env ^
-v "shared:/var/lib/shared:ro" ^
-d ^
honeur/user-mgmt:%TAG% >nul 2>&1

echo Connect user-mgmt to honeur-net network
docker network connect honeur-net user-mgmt >nul 2>&1

echo Clean up helper files
DEL /Q user-mgmt.env

echo Done