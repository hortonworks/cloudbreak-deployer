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

    echo "export ${1}=\"$(escape-string-env ${2} '"')\"" >> $CBD_PROFILE
}

remove-variable-from-profile() {
    declare desc="Remove variable from the Profile"
    : ${1:=required}
    
    local tmp="$CBD_PROFILE.$(date +"%s")"
    cat $CBD_PROFILE | grep -v "export ${1}=" > $tmp
    mv $tmp $CBD_PROFILE
}