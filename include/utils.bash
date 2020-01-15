compare-versions () {
    if [[ $1 == $2 ]]
    then
        echo 0
        return
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            echo 1
            return
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            echo 2
            return
        fi
    done
    echo 0
}

is_linux() {
    [[ "$(uname)" == Linux ]]
}

is_macos() {
    [[ "$(uname)" == Darwin ]]
}

docker-ip() {
    if [[ $DOCKER_HOST =~ "tcp://" ]];then
        local dip=${DOCKER_HOST#*//}
        echo ${dip%:*}
    else
        echo none
    fi
}

gen-password() {
    date +%s | checksum sha1 | head -c 10
}

escape-string-env() {
    declare desc="Escape yaml string by delimiter type"
    : ${2:=required}
    local in=$1
    local delimiter=$2

    if [[ $delimiter == "'" ]]; then
        out=`echo $in | sed -e "s/'/'\\\\\\''/g"`
    elif [[ $delimiter == '"' ]]; then
        out=`echo $in | sed -e 's/\\\\/\\\\\\\/g' -e 's/"/\\\"/g' -e 's/[$]/\$/g' -e "s/\\\`/\\\\\\\\\\\\\\\`/g" -e 's/!/\\\\!/g'`
    else
        out="$in"
    fi

    echo $out
}

escape-string-json() {
    declare desc="Escape json string"
    : ${1:=required}
    local in=$1

    out=`echo $in | sed -e 's/\\\\/\\\\\\\/g' -e 's/"/\\\"/g'`

    echo $out
}

append-variable-to-profile() {
    declare desc="Append new variable to the end of the Profile"
    : ${1:=required}
    : ${2:=required}

    local var="export ${1}=\"$(escape-string-env ${2} '"')\""
    echo $var >> $CBD_PROFILE
    eval $var
}

remove-variable-from-profile() {
    declare desc="Remove variable from the Profile"
    : ${1:=required}

    local tmp="$CBD_PROFILE.$(date +"%s")"
    cat $CBD_PROFILE | grep -v "export ${1}=" > $tmp
    mv $tmp $CBD_PROFILE
}

exit-on-remote-database() {
    case $1 in
    cbdb*)
        db="$CB_DB_PORT_5432_TCP_ADDR"
    ;;
    periscopedb*)
        db="$PERISCOPE_DB_PORT_5432_TCP_ADDR"
    ;;
    *)
        error "Database not supported $1"
        _exit 235
    ;;
    esac

    if [[ -n "$db" ]] && [[ $db != "$COMMON_DB"* ]]; then
        error "Remote database not supported as $1"
        _exit 543
    fi
}
