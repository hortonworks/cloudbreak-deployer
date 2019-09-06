
shorten_function() {
  local max=25
  local context=5
  local word="$*"

  if [[ ${#word} -le ${max} ]]; then
      echo "${word}"
  else
      local keep=$(( ${#word} - (${max} - ${context} - 2) ))
      echo "${word:0:${context}}..${word:$keep}"
  fi
}
debug() {
  if [[ "$DEBUG" ]]; then
      if [[ "$DEBUG" -eq 2 ]]; then
          printf "[DEBUG][%-25s] %s\n" $(shorten_function "${FUNCNAME[1]}") "$*" | gray 1>&2
      else
        echo -e "[DEBUG] $*" | gray 1>&2
      fi
  fi
}

debug-cat() {
  if [[ "$DEBUG" ]]; then
      gray 1>&2
  else
      cat &> /dev/null
  fi
}

echo-n () {
    echo -n "$*" 1>&2
}

info() {
    echo "$*" | green 1>&2
}

warn() {
    echo "[WARN] $*" | yellow 1>&2
}

error() {
    echo "[ERROR] $*" | red 1>&2
}

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

echo_if_not_contains() {
    if [[ "$1" != *"$2"* ]]; then
        echo "$2"
    fi
}

setup_proxy_environments() {
    if [[ "$HTTP_PROXY_HOST" ]] || [[ "$HTTPS_PROXY_HOST" ]]; then
         if [[ "$HTTP_PROXY_HOST" ]]; then
            PROXY_HOST=$HTTP_PROXY_HOST
         else
            PROXY_HOST=$HTTPS_PROXY_HOST
         fi

         for PROXY_PROTOCOL in http https; do
             HTTP_PROXY="http://"
             HTTPS_PROXY="https://"
             if [[ "$PROXY_USER" ]] &&  [[ "$PROXY_PASSWORD" ]]; then
                CB_JAVA_OPTS+=$(echo_if_not_contains "$CB_JAVA_OPTS" " -D$PROXY_PROTOCOL.proxyUser=$PROXY_USER")
                CB_JAVA_OPTS+=$(echo_if_not_contains "$CB_JAVA_OPTS" " -D$PROXY_PROTOCOL.proxyPassword=$PROXY_PASSWORD")
                HTTP_PROXY+="$PROXY_USER:$PROXY_PASSWORD@"
                HTTPS_PROXY+="$PROXY_USER:$PROXY_PASSWORD@"
             fi

             CB_JAVA_OPTS+=$(echo_if_not_contains "$CB_JAVA_OPTS" " -D$PROXY_PROTOCOL.proxyHost=$PROXY_HOST")
             HTTP_PROXY+="$PROXY_HOST"
             HTTPS_PROXY+="$PROXY_HOST"

             if [[ "$PROXY_PORT" ]]; then
                CB_JAVA_OPTS+=$(echo_if_not_contains "$CB_JAVA_OPTS" " -D$PROXY_PROTOCOL.proxyPort=$PROXY_PORT")
                HTTP_PROXY+=":$PROXY_PORT"
                HTTPS_PROXY+=":$PROXY_PORT"
             fi
         done

         if [[ "$NON_PROXY_HOSTS" ]]; then
            CB_JAVA_OPTS+=$(echo_if_not_contains "$CB_JAVA_OPTS" " -Dhttp.nonProxyHosts=\"$NON_PROXY_HOSTS\"")
         fi
         export http_proxy=$HTTP_PROXY
         export https_proxy=$HTTPS_PROXY
    fi
}

curl-proxy-aware() {
    cloudbreak-conf-proxy
    env-import CURL_CONNECT_TIMEOUT 20
    local CURL_ARGS="--connect-timeout $CURL_CONNECT_TIMEOUT"
    setup_proxy_environments
    if [[ "$HTTP_PROXY_HOST" ]] || [[ "$HTTPS_PROXY_HOST" ]]; then
        if [[ "$HTTP_PROXY_HOST" ]]; then
            CURL_ARGS+=" --proxy $HTTP_PROXY"
        elif [[ "$HTTPS_PROXY_HOST" ]]; then
            CURL_ARGS+=" --proxy $HTTPS_PROXY"
        fi
        if [[ "$NON_PROXY_HOSTS" ]]; then
            CURL_ARGS+=" --noproxy "
            CURL_ARGS+=$(echo "\"$NON_PROXY_HOSTS\"" | sed 's/|/,/g' )
        fi
    fi

    curl ${CURL_ARGS} "$@"
}

cbd-version() {
    declare desc="Displays the version of Cloudbreak Deployer"
    echo -n "local version:"
    local localVer=$(bin-version)
    echo "$localVer" | green

    echo -n "latest release:"
    local releaseVer=$(latest-version)
    echo "$releaseVer" | green

    if [[ "$releaseVer" ]] && [ $(version-compare ${localVer#v} $releaseVer) -lt 0 ]; then
        warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        warn "Your version is outdated"
        warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        warn "Please update it by:"
        echo "  cbd update" | blue
    fi

    if [ -e docker-compose.yml ]; then
        echo "docker images:"
        sed -n "s/.*image://p" docker-compose.yml | grep "sequenceiq\|hortonworks" |green
    fi

}

cbd-update() {
    declare desc="Binary selfupdater. Updates to lates official release"

    if [[ "$1" ]]; then
        # cbd-update-snap $1
        warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        warn "Update doesn't support any parameter"
        warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo 'Please use "cbd update" to get the latest official release or contact support if you would like to update to an unsupported version.' | red
        _exit 1
    else
        cbd-update-release
    fi
}

cbd-update-release() {
    declare desc="Updates itself from github release"

    local binver=$(bin-version)
    local lastver=$(latest-version)
    local osarch=$(uname -sm | tr " " _ )
    debug $desc
    debug binver=$binver lastver=$lastver osarch=$osarch | gray

    if [[ ! "$lastver" ]]; then
        error "Could not get latest version. Update terminated"
        _exit 1
    fi

    if [[ ${binver} != ${lastver} ]]; then
        debug upgrade needed |yellow

        if docker volume inspect $COMMON_DB_VOL &>/dev/null; then
            info "Backing up databases"

	    for db in $CB_DB_ENV_DB $PERISCOPE_DB_ENV_DB $DATALAKE_DB_ENV_DB $ENVIRONMENT_DB_ENV_DB $REDBEAMS_DB_ENV_DB $FREEIPA_DB_ENV_DB; do
                debug "Backing up $db"
                db-dump $db
            done
        fi

        local url=https://github.com/hortonworks/cloudbreak-deployer/releases/download/v${lastver}/cloudbreak-deployer_${lastver}_${osarch}.tgz
        info "Updating $SELF_EXECUTABLE from url: $url"
        curl-proxy-aware -Ls $url | tar -zx -C $TEMP_DIR
        mv $TEMP_DIR/cbd $SELF_EXECUTABLE
        debug $SELF_EXECUTABLE is updated
    else
        debug you have the latest version | green
    fi
}

cbd-update-snap() {
    declare desc="Updates itself, from CircleCI branch artifact"
    declare branch=${1:?branch name is required}

    url=$(cci-latest hortonworks/cloudbreak-deployer $branch)
    info "Update $SELF_EXECUTABLE from: $url"
    curl-proxy-aware -Ls $url | tar -zx -C $TEMP_DIR
    mv $TEMP_DIR/cbd $SELF_EXECUTABLE
    debug $SELF_EXECUTABLE is updated
}

latest-version() {
    #curl -Ls https://raw.githubusercontent.com/hortonworks/cloudbreak-deployer/master/VERSION
    LATEST_URL="https://github.com/hortonworks/cloudbreak-deployer/releases/latest"

    VERSION=$(curl-proxy-aware -I $LATEST_URL 2>&1)
    RET=$?
    if  [[ "$RET" != 0 ]]; then
        error "curl returned with error $RET"

        if [[ "$HTTP_PROXY_HOST" ]] || [[ "$HTTPS_PROXY_HOST" ]]; then
            warn "Couldn't get latest version. Check your proxy settings in your Profile"
        fi
    else
        echo "$VERSION" | sed -n "s/^Location:.*tag.v\([0-9\.]*\).*/\1/p"
    fi
}

public-ip-resolver-command() {
    declare desc="Generates command to resolve public IP"

    if is_linux; then
        # on gce
        if curl -m 1 -f -s -H "Metadata-Flavor: Google" 169.254.169.254/computeMetadata/v1/ &>/dev/null ; then
            echo "curl -m 1 -f -s -H \"Metadata-Flavor: Google\" 169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip"
            return
        fi

        # on amazon
        if curl -m 1 -f -s 169.254.169.254/latest/dynamic &>/dev/null ; then
            if curl -m 1 -f -s 169.254.169.254/latest/meta-data/public-hostname &>/dev/null ; then
                echo "curl -m 1 -f -s 169.254.169.254/latest/meta-data/public-hostname"
            else
                if curl -m 1 -f -s 169.254.169.254/latest/meta-data/local-ipv4 &>/dev/null ; then
                     echo "curl -m 1 -f -s 169.254.169.254/latest/meta-data/local-ipv4"
                else
                    warn "Public hostname not found setting up loopback as PUBLLIC_IP"
                    echo "echo 127.0.0.1"
                fi
            fi
            return
        fi

        # on openstack
        if curl -m 1 -f -s 169.254.169.254/latest &>/dev/null ; then
            if [[ -n "$(curl -m 1 -f -s 169.254.169.254/latest/meta-data/public-ipv4)" ]]; then
                echo "curl -m 1 -f -s 169.254.169.254/latest/meta-data/public-ipv4"
            else
                warn "Public ip not found setting up private as PUBLLIC_IP"
                echo "curl -m 1 -f -s 169.254.169.254/latest/meta-data/local-ipv4"
            fi
            return
        fi

        #on azure
        if curl -m 1 -f -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-03-01" &>/dev/null ; then
            echo -n "curl -H Metadata:true 'http://169.254.169.254/metadata/instance?api-version=2017-03-01' | jq -r '.network.interface[].ipv4.ipaddress[] | select(.publicip != null and .publicip != \"\") | .publicip' | head -1"
            return
        fi
    fi
}

start-time-init() {
    declare desc="Resolve or set Cloudbreak deployment start time"

    if ! [[ "$(cat .starttime 2> /dev/null)" ]]; then
        echo "$(date +%s)" > .starttime
    fi
    export CB_COMPONENT_CREATED=$(cat .starttime)
}

init-profile() {
    declare desc="Creates Profile if missing"

    if [ -f $CBD_PROFILE ]; then
        debug "Use existing profile: $CBD_PROFILE"
        module-load "$CBD_PROFILE"
    fi

    if ! [[ "$CB_INSTANCE_UUID" ]]; then
        debug "Instance UUID not found, let's generate one"
        append-variable-to-profile CB_INSTANCE_UUID "$(uuidgen | tr '[:upper:]' '[:lower:]')"
    fi

    if ! [[ "$CB_INSTANCE_NODE_ID" ]]; then
        debug "Instance node UUID not found, let's generate one"
        append-variable-to-profile CB_INSTANCE_NODE_ID "$(uuidgen | tr '[:upper:]' '[:lower:]')"
    fi

    provider-and-region-init
}

load-profile() {
    declare desc="Loads Profile"

    module-load "$CBD_PROFILE"

    if [[ "$CBD_DEFAULT_PROFILE" && -f "Profile.$CBD_DEFAULT_PROFILE" ]]; then
		module-load $"Profile.$CBD_DEFAULT_PROFILE"
		debug "Using profile $CBD_DEFAULT_PROFILE"
	fi
}

public-ip-init() {
    declare desc="Tries to guess PUBLIC_IP if not found"

    if is_macos; then
        debug "PUBLIC_IP and CB_TRAEFIK_HOST_ADDRESS will be 127.0.0.1"
        export PUBLIC_IP="127.0.0.1"
        export CB_TRAEFIK_HOST_ADDRESS="localhost"
    fi

    if [[ ! "$PUBLIC_IP" ]]; then
        debug "PUBLIC_IP not found, try to guess"
        ipcommand=$(public-ip-resolver-command)
        if [[ "$ipcommand" ]]; then
            export PUBLIC_IP=$(eval "$ipcommand")
            debug "Used PUBLIC_IP: $PUBLIC_IP"
        else
            warn "We can not guess your PUBLIC_IP, please run the following command: (replace 1.2.3.4 with a real IP)"
            if is_macos; then
                warn "On Mac OS the PUBLIC_IP should be the Docker host's bridge ip"
            fi
            echo "echo export PUBLIC_IP=1.2.3.4 >> $CBD_PROFILE" | blue
            _exit 2
        fi
    fi
}

provider-and-region-init() {
    declare desc="Estimate the provider and the region of instance if they are defined in the Profile"

    if ! [ "$CB_INSTANCE_PROVIDER" ] && ! [ "$CB_INSTANCE_REGION" ]; then
        debug "Provider and region of the instance could not be found, estimating them..."

        export CB_INSTANCE_PROVIDER="unknown"
        export CB_INSTANCE_REGION="unknown"

        if is_linux; then
            # on gcp
            if curl -m 1 -f -s -H "Metadata-Flavor: Google" 169.254.169.254/computeMetadata/v1/ &>/dev/null ; then
                CB_INSTANCE_PROVIDER="gcp"
                CB_INSTANCE_REGION=$(curl -m 1 -f -s -H "Metadata-Flavor: Google" 169.254.169.254/computeMetadata/v1/instance/zone | sed 's/.*\///g')
            # on amazon
            elif curl -m 1 -f -s 169.254.169.254/latest/dynamic &>/dev/null ; then
                CB_INSTANCE_PROVIDER="aws"
                CB_INSTANCE_REGION=$(curl -m 1 -f -s 169.254.169.254/latest/meta-data/placement/availability-zone)
            # on openstack
            elif curl -m 1 -f -s 169.254.169.254/latest &>/dev/null ; then
                CB_INSTANCE_PROVIDER="openstack"
                CB_INSTANCE_REGION=$(curl -m 1 -f -s 169.254.169.254/latest/meta-data/placement/availability-zone)
            #on azure
            elif curl -m 1 -f -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-03-01" &>/dev/null ; then
                CB_INSTANCE_PROVIDER="azure"
                CB_INSTANCE_REGION=$(curl -H Metadata:true 'http://169.254.169.254/metadata/instance?api-version=2017-03-01' | jq -r '.compute.location')
            fi
        fi

        append-variable-to-profile CB_INSTANCE_PROVIDER "$CB_INSTANCE_PROVIDER"
        append-variable-to-profile CB_INSTANCE_REGION "$CB_INSTANCE_REGION"
    fi
}

doctor() {
    declare desc="Deployer doctor: Checks your environment, and reports a diagnose."

    info "===> $desc"
    echo-n "uname: "
    uname -a | green
    cbd-version
    if [[ "$(uname)" == "Darwin" ]]; then
        debug "checking OSX specific dependencies..."

        if [[ $(is-sub-path $(dirname ~/.) $(pwd)) == 0 ]]; then
          info "deployer location: OK"
        else
          error "Please relocate deployer under your home folder. On OSX other locations are not supported."
          _exit 1
        fi
    fi

    docker-check-version
    network-doctor
    localdev-doctor
    if [[ -e docker-compose.yml ]]; then
        compose-generate-check-diff verbose
    fi
    if [[ -e traefik.toml ]]; then
        generate-traefik-check-diff verbose
    fi
}

localdev-doctor() {
    localdev-doctor-service "cloudbreak" "9091"
    localdev-doctor-service "periscope" "8085"
    localdev-doctor-service "datalake" "8086"
    localdev-doctor-service "redbeams" "8087"
    localdev-doctor-service "environment" "8088"
    localdev-doctor-service "freeipa" "8090"
    localdev-doctor-service "cluster-proxy" "10081"
    localdev-doctor-service "idbmms" "8990"
    localdev-doctor-service "environments2-api" "8984"
}

localdev-doctor-service() {
    if [[ $CB_LOCAL_DEV_LIST == *"$1"* ]]; then
        echo "$1 is in local-dev mode (container not started)"
        echo-n "$1 container status: "
        if docker inspect ${CB_COMPOSE_PROJECT}_${1}_1 &> /dev/null; then
            error "$1  container is running."
        else
            info "OK (not running)"
        fi
        echo-n "Local $1 status: "
        if curl -s localhost:"$2" &> /dev/null; then
            info "OK"
        else
            error "$1 is not running on localhost, port $2"
        fi
    fi
}

network-doctor() {
    if [[ "$SKIP_NETWORK_DOCTOR" ]] || [[ "$HTTP_PROXY_HOST" ]] || [[ "$HTTPS_PROXY_HOST" ]]; then
        info "network checks are skipped in case you are using proxy"
        return
    fi

    echo-n "ping 8.8.8.8 on host: "
    if ping -c 1 -W 1 8.8.8.8 &> /dev/null; then
        info "OK"
    else
        error
    fi

    echo-n "ping github.com on host: "
    if ping -c 1 -W 1 github.com &> /dev/null; then
        info "OK"
    else
        error
    fi

    echo-n "ping 8.8.8.8 in container: "
    if docker run --rm --name=cbreak_doctor_gdns --label cbreak.sidekick=true alpine sh -c 'ping -c 1 -W 1 8.8.8.8' &> /dev/null; then
        info "OK"
    else
        error
    fi

    echo-n "ping github.com in container: "
    if docker run --rm --name=cbreak_doctor_github --label cbreak.sidekick=true alpine sh -c 'ping -c 1 -W 1 github.com' &> /dev/null; then
        info "OK"
    else
        error
    fi
}

cbd-find-root() {
    CBD_ROOT=$PWD
}

is-sub-path() {
  declare desc="Checks first path contains secound one"

  declare reference_path=$1
  declare path=$2
  local reference_size=${#reference_path}
  [[ $reference_path == ${path:0:$reference_size} ]]
  echo $?
}

deployer-delete() {
    declare desc="Deletes yaml files, and all dbs. You can use '--force' to avoid confirm dialog"

    cloudbreak-conf-db

    if [[ "$1" != "--force" ]] ; then
        read -r -t 10 -p "Are you sure you would like to wipe all Cloudbreak related data? [y/N] " response
        if ! [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
            info "Delete terminated for user request"
            _exit 0
        fi
    fi

    cloudbreak-delete-dbs
    cloudbreak-delete-vault-data
}

deployer-generate() {
    declare desc="Generates docker-compose.yml"

    cloudbreak-generate-cert
    compose-generate-yaml
    generate-vault-config
    generate-toml-file-for-localdev
    generate-caddy-file-for-localdev
}

deployer-regenerate() {
    declare desc="Backups and generates new docker-compose.yml"

    regeneteInProgress=1
    : ${datetime:=$(date +%Y%m%d-%H%M%S)}
    cloudbreak-generate-cert

    if ! compose-generate-check-diff; then
        info renaming: docker-compose.yml to: docker-compose-${datetime}.yml
        mv docker-compose.yml docker-compose-${datetime}.yml
    fi
    compose-generate-yaml

    if ! generate_vault_check_diff; then
            info renaming: $VAULT_CONFIG_FILE to: vault-config-${datetime}.yml
            mv $VAULT_CONFIG_FILE vault-config-${datetime}.yml
    fi
    generate-vault-config

    if ! generate-traefik-check-diff; then
            info renaming: traefik.toml to: traefik-${datetime}.toml
            mv traefik.toml traefik-${datetime}.toml
    fi
    generate-toml-file-for-localdev
    generate-caddy-file-for-localdev
}

escape-string-yaml() {
    declare desc="Escape yaml string by delimiter type"
    : ${2:=required}
    local in=$1
    local delimiter=$2

    if [[ $delimiter == "'" ]]; then
        out=`echo $in | sed -e "s/'/''/g"`
    elif [[ $delimiter == '"' ]]; then
		out=`echo $in | sed -e 's/\\\\/\\\\\\\/g' -e 's/"/\\\"/g'`
    else
        out="$in"
    fi

    echo $out
}

deployer-login() {
    declare desc="Shows Uluwatu (Cloudbreak UI) login url and credentials"

    # TODO it shoudn't be called multiple times ...
    cloudbreak-config
    info "Uluwatu (Cloudbreak UI) url:"
    echo "  $ULU_HOST_ADDRESS" | blue
}

start-cmd() {
    declare desc="Starts Cloudbreak Deployer containers"

    start-requested-services "$@"
    deployer-login
}

restart-cmd() {
    declare desc="shortcut for kill + regenerate + start"

    compose-kill
    deployer-regenerate
    start-requested-services
}

start-wait-cmd() {
    declare desc="Starts Cloudbreak Deployer containers, and waits until API is available"

    start-requested-services "$@"
    wait-for-service "cloudbreak" "cb" "$CB_HOST_ADDRESS"
    wait-for-service "environment" "environmentservice" "$ENVIRONMENT_HOST_ADDRESS"	
    wait-for-service "periscope" "as" "$PERISCOPE_HOST_ADDRESS"	
    wait-for-service "redbeams" "redbeams" "$REDBEAMS_HOST_ADDRESS"		
    wait-for-service "freeipa" "freeipa" "$FREEIPA_HOST_ADDRESS"		
    wait-for-service "datalake" "dl" "$DATALAKE_HOST_ADDRESS"
    deployer-login
}

start-requested-services() {
    declare services="$@"

    if [ ! -f "etc/license.txt" ]; then
      error "License file not found (etc/license.txt). Please provide a license file.";
      _exit 1
    fi

    cloudbreak-config

    deployer-generate
    db-initialize-databases

    if ! [[ "$services" ]]; then
        debug "All services must be started"
        if [[ "$(docker-compose -p cbreak ps $COMMON_DB | tail -1)" == *"Up"* ]]; then
            debug "DB services: $COMMON_DB are already running, start only other services"
            services=$(yq r -j docker-compose.yml | jq -r ".services|keys[]" | grep -v "db$" | xargs)
        fi
    fi

    if [[ -z "$services" || "$services" == *"vault"* ]]; then
        init_vault
    fi

    compose-pull || :
    compose-up $services
}

wait-for-service() {
    if ! [[ $CB_LOCAL_DEV_LIST == *"$1"* ]]; then
        info "Waiting for $1 UI (timeout: $CB_UI_MAX_WAIT)"
        debug "sending curl to: $3/$2/info"
        local curl_cmd="curl -so /dev/null -w "%{http_code}" $3/$2/info"
        local count=0
        while ! $curl_cmd |grep 200 &> /dev/null && [ $((count++)) -lt $CB_UI_MAX_WAIT ] ; do
            echo -n . 1>&2
            sleep 1;
        done
        echo 1>&2
        if ! $curl_cmd; then
            error "Could not reach $1 in time."
            info "print logs of failed container"
            docker logs "cbreak_$1_1"
            _exit 1
        fi
    fi
}

create-temp-dir() {
    debug "Creating '.tmp' directory if not exist"
    TEMP_DIR=$(deps-dir)/tmp
    mkdir -p $TEMP_DIR
}

_exit() {
    docker-kill-all-sidekicks
    exit $1
}

is_command_needs_profile() {
    [[ ' '"bash-complete help machine delete"' ' != *" $1 "* ]]
}

copy_cbd_output_to_log() {
    echo "$(date +"%Y-%m-%d %T") $(whoami) $@" >> .cbd_output_history

    # Save descriptors
    exec 3>&1 4>&2

    # Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
    exec > >(tee -ia .cbd_output_history)

    # stderr to stdout
    exec 2>&1
}

disable_cbd_output_copy_to_log() {
    #restore descriptors
    exec 1>&3 2>&4
}
main() {
    copy_cbd_output_to_log $@

	set -eo pipefail; [[ "$TRACE" ]] && set -x

    CBD_PROFILE="Profile"

    cbd-find-root
    start-time-init
	color-init
    if is_command_needs_profile $1; then
        init-profile
        load-profile
        public-ip-init
    fi
    deps-init
    create-temp-dir
    deps-require sed
    deps-require yq

    circle-init
    compose-init

    debug "Cloudbreak Deployer $(bin-version)"

    cmd-export cmd-help help
    cmd-export cbd-version version
    cmd-export doctor doctor
    cmd-export cmd-bash-complete bash-complete
    cmd-export-ns env "Environment namespace"
    cmd-export env-show
    cmd-export env-export
    cmd-export create-bundle create-bundle

    cmd-export-ns db "Db operations namespace"
    cmd-export db-dump
    cmd-export db-restore

    cmd-export cbd-update update

    cmd-export deployer-generate generate
    cmd-export deployer-regenerate regenerate
    cmd-export deployer-delete delete
    cmd-export deployer-login login
    cmd-export start-cmd start
    cmd-export restart-cmd restart
    cmd-export start-wait-cmd start-wait
    cmd-export compose-ps ps
    cmd-export compose-kill kill
    cmd-export compose-logs logs
    cmd-export compose-logs-tail logs-tail
    cmd-export compose-pull pull

    cmd-export migrate-startdb-cmd startdb
    cmd-export migrate-cmd migrate

    cmd-export-ns util "Util namespace"
    cmd-export util-token
    cmd-export util-token-debug
    cmd-export util-cleanup

    cmd-export-ns vault "Vault management namespace"
    cmd-export vault-unseal
    cmd-export vault-status

    if [[ "$DEBUG" ]]; then
        cmd-export fn-call fn
    fi

    echo "$(date +"%Y-%m-%d %T") $(whoami) $@" >> .cbd_history

	if [[ "${!#}" == "-h" || "${!#}" == "--help" ]]; then
		local args=("$@")
		unset args[${#args[@]}-1]
		cmd-ns "" help "${args[@]}"
	else
		cmd-ns "" "$@"
	fi
    rm -rf $TEMP_DIR
    docker-kill-all-sidekicks
}
