#!/bin/bash

## get passwords
source /opt/seafile-demo-recreate/.env

healthcheck() {
    suffix=$1
    if [ -n "$HEALTHCHECK_URL" ]; then
        curl -fSsL --retry 3 -X POST \
            --user-agent "seafile-demo-recreate/1.0.0" \
            --data-raw "seafile-demo" "${HEALTHCHECK_URL}${suffix}"
        if [ $? != 0 ]; then
            exit 1
        fi
    fi
}

healthcheck /start

## stop old containers
cd /opt/seafile-compose
docker compose down --remove-orphans

## remove old stuff
rm -r /opt/seafile-server
rm -r /opt/mariadb
rm -r /opt/seadoc-data
rm -r /opt/seasearch-data
rm -r /opt/notification-data

## TODO: kann weg...
#rm -r /opt/seatable-demo-recreate/files/output/template_token.txt # da kommt der base_api_token von templates base rein...

## TODO: später
## copy certs
mkdir -p /opt/seafile-server/certs
cp /opt/seafile-demo-recreate/files/certs/* /opt/seafile-server/certs/

## customizing
# I mount the logo, background and css as volume in the seafile.yml file.

## restart
docker compose pull
docker compose up -d

## wait until Seafile is available
TIMEOUT=120             # Total timeout duration in seconds (2 minutes)
INTERVAL=10             # Interval between pings in seconds
start_time=$(date +%s)  # start time

while true; do
  if curl --silent --fail "${SEAFILE_URL}/api2/ping/" > /dev/null; then
    echo "Seafile Server is available. Continuing..."
    break
  else
    echo "${SEAFILE_URL} is not available. Checking again in $INTERVAL seconds..."
  fi
  current_time=$(date +%s) # Check if the timeout has been reached
  elapsed_time=$((current_time - start_time))

  if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
    echo "Timeout reached. Exiting..."
    exit 1
  fi
  sleep "$INTERVAL" # Wait for the specified interval before retrying
done

## update seahub_settings.py (sollte später alles über env gehen...)
printf "%b(7): add seahub_settings.py configuration %b\n" "$RED" "$NC"
echo "

#BRANDING_CSS = 'custom/custom.css'

# MULTI TENANCY MODE
CLOUD_MODE = True
ENABLE_GLOBAL_ADDRESSBOOK = True
MULTI_TENANCY = True
ORG_MEMBER_QUOTA_ENABLED = True

## User Management (https://manual.seafile.com/config/seahub_settings_py.html)
ENABLE_SIGNUP = False
FORCE_PASSWORD_CHANGE = False
LOGIN_ATTEMPT_LIMIT = 5

# ROLES AND PERMISSIONS
#ENABLED_ROLE_PERMISSIONS = {
#    'default': {
#        ...
#}
ENABLE_DELETE_ACCOUNT = False

# collabora
OFFICE_SERVER_TYPE = 'CollaboraOffice'
ENABLE_OFFICE_WEB_APP = True
OFFICE_WEB_APP_BASE_URL = '${SEAFILE_URL}:6232/hosting/discovery'
WOPI_ACCESS_TOKEN_EXPIRATION = 30 * 60   # seconds
OFFICE_WEB_APP_FILE_EXTENSION = ('odp', 'ods', 'odt', 'xls', 'xlsb', 'xlsm', 'xlsx','ppsx', 'ppt', 'pptm', 'pptx', 'doc', 'docm', 'docx')
ENABLE_OFFICE_WEB_APP_EDIT = True
OFFICE_WEB_APP_EDIT_FILE_EXTENSION = ('odp', 'ods', 'odt', 'xls', 'xlsb', 'xlsm', 'xlsx','ppsx', 'ppt', 'pptm', 'pptx', 'doc', 'docm', 'docx')

# SAML
#ENABLE_SAML = True
#...

# EMAIL
EMAIL_USE_TLS = True
EMAIL_HOST = '${EMAIL_HOST}'
EMAIL_HOST_USER = '${EMAIL_HOST_USER}'
EMAIL_HOST_PASSWORD = '${EMAIL_HOST_PASSWORD}'
EMAIL_PORT = 587
DEFAULT_FROM_EMAIL = EMAIL_HOST_USER
SERVER_EMAIL = EMAIL_HOST_USER

ENABLE_GUEST_INVITATION = True
SEND_EMAIL_ON_ADDING_SYSTEM_MEMBER = False
SEND_EMAIL_ON_RESETTING_USER_PASSWD = False
NOTIFY_ADMIN_AFTER_REGISTRATION = False

" | tee -a /opt/seafile-server/seafile/conf/seahub_settings.py >/dev/null

## update seafile.conf
echo "
[general]
cloud_mode = true
multi_tenancy = true

[notification]
enabled = true
host = notification-server
port = 8083
" | tee -a /opt/seafile-server/seafile/conf/seafile.conf >/dev/null

echo "
[DATABASE]
type = mysql
host = mariadb
port = 3306
username = seafile
password = topsecret2
name = seahub_db

[SEAHUB EMAIL]
enabled = true
interval = 30m

[STATISTICS]
enabled=true

[AUDIT]
enabled = true

[INDEX FILES]
external_es_server = true
es_host = elasticsearch
es_port = 9200
enabled = false
interval = 10m
highlight = fvh
index_office_pdf = true

[FILE HISTORY]
enabled = true
suffix = md,txt,doc,docx,xls,xlsx,ppt,pptx,sdoc

[SEASEARCH]
enabled = true
seasearch_url = http://seasearch:4080
seasearch_token = ${SEASEARCH_PW}
interval = 10m
" > /opt/seafile-server/seafile/conf/seafevents.conf

# restart and sleep (necessary, otherwise auth-token is not received...)
#docker exec seafile-server /opt/seatable/scripts/seatable.sh
#sleep 30

# create users TODO: noch einbauen...
#printf "%b(10): create all users %b\n" "$RED" "$NC"
#cd /opt/seatable-demo-recreate/files/init_docker
#docker build --no-cache -t php-init .
#docker run --rm \
# -v $(pwd)/createOrgsTemplatesPlugins.php:/app/createOrgsTemplatesPlugins.php \
# -v $(pwd)/../templates:/tmp/templates \
# -v $(pwd)/../plugins:/tmp/plugins \
# -v $(pwd)/../avatars:/tmp/avatars \
# -v $(pwd)/../output:/tmp/output \
# -v $(pwd)/../../.env:/tmp/.env \
#php-init


## final restart
docker compose down
docker compose up -d

start_time=$(date +%s)  # start time
while true; do
  if curl --silent --fail "${SEAFILE_URL}/api2/ping/" > /dev/null; then
    break
  fi
  current_time=$(date +%s) # Check if the timeout has been reached
  elapsed_time=$((current_time - start_time))

  if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
    echo "Seafile Server is not ready!"
    healthcheck /fail
    exit 1
  fi
  sleep "$INTERVAL" # Wait for the specified interval before retrying
done

# CREATE USERS 
TOKEN=$(/usr/bin/curl -s -d "username=${ADMIN_UN}&password=${ADMIN_PW}" "${SEAFILE_URL}/api2/auth-token/" | /usr/bin/jq -r ".token")
curl -H "Authorization: Token ${TOKEN}" -F "avatar=@/opt/seafile-demo-recreate/files/avatars/admin.png" -F "avatar_size=64" "${SEAFILE_URL}/api/v2.1/user-avatar/"

function create_user(){
    USERACCOUNT=$(curl -X POST -d "email=${1}@datamate.org&password=${DEFAULT_PW}&name=${2}&is_staff=${3}" -H "Authorization: Token ${TOKEN}" -H 'Accept: application/json; indent=4' "${SEAFILE_URL}/api/v2.1/admin/users/" | /usr/bin/jq -r ".email" )
    USERTOKEN=$(/usr/bin/curl -s -d "username=${1}@datamate.org&password=${DEFAULT_PW}" "${SEAFILE_URL}/api2/auth-token/" | /usr/bin/jq -r ".token")
    curl -H "Authorization: Token ${USERTOKEN}" -F "avatar=@/opt/seafile-demo-recreate/files/avatars/${1}.png" -F "avatar_size=64" "${SEAFILE_URL}/api/v2.1/user-avatar/"
    curl -d "name=Bibliothek (verschlüsselt)&passwd=${DEFAULT_PW}" -H "Authorization: Token $USERTOKEN" -H 'Accept: application/json; indent=4' "${SEAFILE_URL}/api2/repos/"
    # bib_import muss an der richtigen stelle liegen. per mount...
    #docker exec seafile-server /opt/seafile/seafile-server-latest/seaf-import.sh -p /shared/seafile/bib_import/bibliothek_a -n 'Bibliothek-A' -u "${1}@datamate.org"
    #docker exec seafile-server /opt/seafile/seafile-server-latest/seaf-import.sh -p /shared/seafile/bib_import/bibliothek_b -n 'Bibliothek-B' -u "${1}@datamate.org"
    curl -X PUT -d "login_id=${1}" -H "Authorization: Token ${TOKEN}" -H 'Accept: application/json; charset=utf-8; indent=4' "${SEAFILE_URL}/api/v2.1/admin/users/${USERACCOUNT}/"
}

create_user "hulk" "Hulk" false
create_user "steve" "Steve" false
create_user "tony" "Tony" false
create_user "thor" "Thor" false
create_user "ernie" "Ernie" false
create_user "bert" "Bert" false
create_user "monster" "Krümmelmonster" false
create_user "elmo" "Elmo" false


healthcheck /0
echo "Seafile Server is ready..."

