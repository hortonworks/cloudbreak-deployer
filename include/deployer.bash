
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

info() {
    echo "$*" | green 1>&2
}

warn() {
    echo "[WARN] $*" | yellow 1>&2
}

error() {
    echo "[ERROR] $*" | red 1>&2
}

cbd-version() {
    declare desc="Displays the version of Cloudbreak Deployer"
    echo -n "local version:"
    local localVer=$(bin-version)
    echo "$localVer" | green

    echo -n "latest release:"
    local releaseVer=$(latest-version)
    echo "$releaseVer" | green

    if [ $(version-compare $localVer $releaseVer) -lt 0 ]; then
        warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        warn "Your version is outdated"
        warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        warn "Please update it by:"
        echo "  cbd update" | blue
    fi
}

cbd-update() {
    declare desc="Binary selfupdater. Either latest github release (default), or specific branch from CircleCI"

    if [[ "$1" ]]; then
        cbd-update-snap $1
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

    if [[ ${binver} != ${lastver} ]]; then
        debug upgrade needed |yellow

        local url=https://github.com/sequenceiq/cloudbreak-deployer/releases/download/v${lastver}/cloudbreak-deployer_${lastver}_${osarch}.tgz
        info "Updating $SELF_EXECUTABLE from url: $url"
        curl -Ls $url | tar -zx -C $TEMP_DIR
        mv $TEMP_DIR/cbd $SELF_EXECUTABLE
        debug $SELF_EXECUTABLE is updated
    else
        debug you have the latest version | green
    fi
}

cbd-update-snap() {
    declare desc="Updates itself, from CircleCI branch artifact"
    declare branch=${1:?branch name is required}

    url=$(cci-latest sequenceiq/cloudbreak-deployer $branch)
    info "Update $SELF_EXECUTABLE from: $url"
    curl -Ls $url | tar -zx -C $TEMP_DIR
    mv $TEMP_DIR/cbd $SELF_EXECUTABLE
    debug $SELF_EXECUTABLE is updated
}

latest-version() {
  #curl -Ls https://raw.githubusercontent.com/sequenceiq/cloudbreak-deployer/master/VERSION
  curl -I https://github.com/sequenceiq/cloudbreak-deployer/releases/latest 2>&1 \
      |sed -n "s/^Location:.*tag.v\([0-9\.]*\).*/\1/p"
}

init-profile() {
    declare desc="Creates Profile if missing"

    CBD_PROFILE="Profile"

    # if the profile exist
    if [ -f $CBD_PROFILE ]; then
        info "$CBD_PROFILE already exists, now you are ready to run:"
        echo "cbd generate" | blue
    else
        if is_linux; then
            # on amazon
            if curl -m 1 -f 169.254.169.254/latest/ &>/dev/null ; then
                echo "export PUBLIC_IP=$(curl 169.254.169.254/latest/meta-data/public-hostname)" > $CBD_PROFILE
                #echo "export PRIVATE_IP=$(curl 169.254.169.254/latest/meta-data/local-ipv4)" >> $CBD_PROFILE
            fi

            # on openstack
            if curl -m 1 -f  169.254.169.254/latest/meta-data/public-hostname | grep -q novalocal ; then
                echo "export PUBLIC_IP=$(curl 169.254.169.254/latest/meta-data/public-ipv4)" > $CBD_PROFILE
            fi
            
            # on gce
            if curl -m 1 -f -H "Metadata-Flavor: Google" 169.254.169.254/computeMetadata/v1/ &>/dev/null ; then
                echo "export PUBLIC_IP=$(curl -f -H "Metadata-Flavor: Google" 169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)" > $CBD_PROFILE
            fi

            # if Profile is still not created, give some hint:
            if ! [ -f $CBD_PROFILE ]; then
                warn "We can not guess your PUBLIC_IP, please run the following command: (replace 1.2.3.4 with a real IP)"
                echo "echo export PUBLIC_IP=1.2.3.4 > $CBD_PROFILE" | blue
            fi
        else
            if [[ "$(boot2docker status)" == "running" ]]; then
                echo "export PUBLIC_IP=$(boot2docker ip)" > $CBD_PROFILE
                echo "export PRIVATE_IP=$(boot2docker ip)" >> $CBD_PROFILE
                boot2docker shellinit 2>/dev/null >> $CBD_PROFILE
            else
                echo "boot2docker isn't running, please start it, with the following 2 commands:" | red
                echo "boot2docker start" | blue
                echo ' eval "$(boot2docker shellinit)"' | blue
            fi
        fi
        _exit 2
    fi

    doctor
}

load-profile() {

    CBD_PROFILE="Profile"
    if [ -f $CBD_PROFILE ]; then
        debug "Use profile: $CBD_PROFILE"
        module-load "$CBD_PROFILE"
        PROFILE_LOADED=true
    else
        if [[ "$1" != "init" ]];then
            echo "!! No Profile found. Please initalize your 'Profile' with the init command." | red
            echo "cbd init" | blue
        fi
    fi

    if [[ "$CBD_DEFAULT_PROFILE" && -f "Profile.$CBD_DEFAULT_PROFILE" ]]; then
        CBD_PROFILE="Profile.$CBD_DEFAULT_PROFILE"

		module-load $CBD_PROFILE
		debug "Using profile $CBD_DEFAULT_PROFILE"
	fi
}

doctor() {
    declare desc="Deployer doctor: Checks your environment, and reports a diagnose."

    info "===> $desc"
    network-doctor
    cbd-version
    if [[ "$(uname)" == "Darwin" ]]; then
        debug "checking OSX specific dependencies..."
        docker-check-boot2docker
        if [[ $(is-sub-path $(dirname ~/.) $(pwd)) == 0 ]]; then
          info "deployer location: OK"
        else
          error "Please relocate deployer under your home folder. On OSX other locations are not supported."
          _exit 1
        fi
    fi

    docker-check-version
    compose-generate-check-diff verbose
    generate_uaa_check_diff verbose
}

network-doctor() {
    ping -c 1 -W 1 8.8.8.8 &> /dev/null
    if [[ "$?" -ne "0" ]]; then
        error "Could not reach 8.8.8.8."
        _exit 1
    else
        info "ping 8.8.8.8 on host OK"
    fi
    ping -c 1 -W 1 github.com &> /dev/null
    if [[ "$?" -ne "0" ]]; then
        error "Could not reach github.com."
        _exit 1
    else
        info "ping github.com on host OK"
    fi
    docker run --label cbreak.sidekick=true alpine sh -c 'ping -c 1 -W 1 8.8.8.8' &> /dev/null
    if [[ "$?" -ne "0" ]]; then
        error "[ERROR] Could not reach 8.8.8.8 inside a container."
        _exit 1
    else
        info "ping 8.8.8.8 in container OK"
    fi
    docker run --label cbreak.sidekick=true alpine sh -c 'ping -c 1 -W 1 github.com' &> /dev/null
    if [[ "$?" -ne "0" ]]; then
        error "[ERROR] Could not reach github.com inside a container."
        _exit 1
     else
        info "ping github.com in container OK"
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
    declare desc="Deletes yaml files, and all dbs"
    cloudbreak-delete-dbs
    rm -f *.yml
}

deployer-generate() {
    declare desc="Generates docker-compose.yml and uaa.yml"

    cloudbreak-generate-cert
    compose-generate-yaml
    generate_uaa_config
}

deployer-regenerate() {
    declare desc="Backups and generates new docker-compose.yml and uaa.yml"

    regeneteInProgress=1
    : ${datetime:=$(date +%Y%m%d-%H%M%S)}
    cloudbreak-generate-cert

    if ! compose-generate-check-diff; then
        info renaming: docker-compose.yml to: docker-compose-${datetime}.yml
        mv docker-compose.yml docker-compose-${datetime}.yml
    fi
    compose-generate-yaml

    if ! generate_uaa_check_diff; then
        info renaming: uaa.yml to: uaa-${datetime}.yml
        mv uaa.yml uaa-${datetime}.yml
    fi
    generate_uaa_config
}

deployer-login() {
    declare desc="Shows Uluwatu (Cloudbreak UI) login url and credentials"

    # TODO it shoudn't be called multiple times ...
    cloudbreak-config
    info "Uluwatu (Cloudbreak UI) url:"
    echo "  $ULU_HOST_ADDRESS" | blue
    info "login email:"
    echo "  $UAA_DEFAULT_USER_EMAIL" | blue
    info "password:"
    echo "  $UAA_DEFAULT_USER_PW" | blue
}

start-and-migrate-cmd() {
    start-requested-services "$@"
    deployer-login
}

start-wait-and-migrate-cmd() {
    start-requested-services "$@"
    wait-for-cloudbreak
    deployer-login
}

start-requested-services() {
    declare services="$@"

    deployer-generate

    if ! [[ "$services" ]]; then
        debug "All services must be started"
        local dbServices=$(sed -n "/^[a-z]/ s/:.*//p" docker-compose.yml | grep "db$" | xargs)
        local otherServices=$(sed -n "/^[a-z]/ s/:.*//p" docker-compose.yml | grep -v "db$" | xargs)
        if [[ $(docker-compose -p cbreak ps -q $dbServices | wc -l) -eq 3 ]]; then
            debug "DB services: $dbServices are already running, start only other services"
            services="${otherServices}"
        fi
    fi

    create-logfile
    compose-up $services
}

wait-for-cloudbreak() {
    declare max_retry=50
    declare retry_count=1
    while ! $(curl -s -m 1 -f ${CB_HOST_ADDRESS}/info) ; do
      info "Waiting for Cloudbreak...$retry_count"
      ((retry_count++)) && ((retry_count==max_retry)) && break
      sleep 4
    done
    if [[ "$retry_count" -ge "$max_retry" ]]; then
        error "Could not reach Cloudbreak in time."
        _exit 1
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

main() {
	set -eo pipefail; [[ "$TRACE" ]] && set -x

    cbd-find-root
	color-init
    load-profile "$@"
    deps-init
    deps-require sed

    create-temp-dir
    circle-init
    compose-init
    aws-init

    debug "Cloudbreak Deployer $(bin-version)"

    cmd-export cmd-help help
    cmd-export cbd-version version
    cmd-export cbd-update update
    cmd-export doctor doctor
    cmd-export init-profile init

    cmd-export-ns env "Environment namespace"
    cmd-export env-show
    cmd-export env-export

    cmd-export-ns aws "Amazon Webservice namespace"
    cmd-export aws-show-role
    cmd-export aws-generate-role
    cmd-export aws-delete-role
    cmd-export aws-list-roles

    cmd-export-ns azure "Azure namespace"
    cmd-export azure-deploy-dash
    cmd-export azure-configure-arm
    
    if [[ "$PROFILE_LOADED" ]] ; then
        cmd-export deployer-generate generate
        cmd-export deployer-regenerate regenerate
        cmd-export deployer-delete delete
        cmd-export compose-ps ps
        cmd-export start-and-migrate-cmd start
        cmd-export start-wait-and-migrate-cmd start-wait
        cmd-export compose-kill kill
        cmd-export compose-logs logs
        cmd-export compose-pull pull
        cmd-export compose-pull-parallel pull-parallel
        cmd-export deployer-login login

        cmd-export migrate-startdb-cmd startdb
        cmd-export migrate-cmd migrate
        
        cmd-export-ns util "Util namespace"
        cmd-export util-cloudbreak-shell
        cmd-export util-cloudbreak-shell-quiet
        cmd-export util-cloudbreak-shell-remote
        cmd-export util-token
        cmd-export util-local-dev
        cmd-export util-cleanup
    fi

    if [[ "$DEBUG" ]]; then
        cmd-export fn-call fn
    fi

	if [[ "${!#}" == "-h" || "${!#}" == "--help" ]]; then
		local args=("$@")
		unset args[${#args[@]}-1]
		cmd-ns "" help "${args[@]}"
	else
		cmd-ns "" "$@"
	fi
    docker-kill-all-sidekicks
}
