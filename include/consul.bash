consul-recursors() {
    declare desc="Generates consul agent recursor option, by reading the hosts resolv.conf"
    declare resolvConf=${1:? 'required 1.param: resolv.conf file'}
    declare bridge=${2:? 'required 2.param: bridge ip'}
    declare dockerIP=${3:- none}

    local nameservers=$(sed -n "/^nameserver/ s/^.*nameserver[^0-9]*//p;" $resolvConf)
    debug "nameservers on host:\n$nameservers"
    if [[ "$nameservers" ]]; then
        debug bridge=$bridge
        echo "$nameservers" | grep -v "$bridge\|$dockerIP" | sed -n '{s/^/ -recursor /;H;}; $ {x;s/[\n\r]//g;p}'
    else
        echo
    fi
}

cloudbreak-delete-consul-data() {
    declare desc="Deletes consul data-dir (volume)"

    if [[ $(docker-compose -p cbreak ps -q consul | wc -l) -eq 1 ]]; then
        error "Consul container is running, delete not allowed"
        _exit 1
    fi
    docker volume rm consul-data 1>/dev/null || :
}