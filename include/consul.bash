consul-recursors() {
    declare desc="Generates consul agent recursor option, by reading the hosts resolv.conf"
    declare resolvConf=${1:? 'required 1.param: resolv.conf file'}
    declare bridge=${2:? 'required 2.param: bridge ip'}
    declare dockerIP=${3:- none}

    local nameservers=$(sed -n "/^nameserver/ s/^.*nameserver[^0-9]*//p;" $resolvConf)
    debug "nameservers on host:\n$nameservers"
    if [[ "$nameservers" ]]; then
        debug bridge=$bridge
        echo "$nameservers" | grep -v "$bridge\|$dockerIP" | sed -n '{s/^/ -recursor "/;s/$/"/;/:/s/"\(.*\)"/"[\1]"/;H;}; $ {x;s/[\n\r]//g;p}'
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

consul-wait() {
    cloudbreak-config

    local maxtry=${RETRY:=30}
    while  [[ -z $(get-consul-leader) ]]; do
        debug "Waiting for Consul to start [tries left: $maxtry]."
        maxtry=$((maxtry-1))
        if [[ $maxtry -gt 0 ]]; then
            sleep 1;
        else
            error "Consul did not start within 30 seconds."
            _exit 1
        fi
    done
}

get-consul-leader() {
    declare desc="Returns the consul leader"
    status=$(docker exec cbreak_consul_1 sh -c 'curl localhost:8500/v1/status/leader 2>/dev/null')
    debug "Consul leader status: $status"
    echo "$status" | jq . -r
}