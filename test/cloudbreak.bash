T_checkSedVersion() {
    (sed --version|grep GNU | grep -q '4.2') &>/dev/null || $T_fail "GNU sed 4.2 not found on PATH."
}

T_consulRecursorOneValid() {
    result=$(consul-recursors <(cat <<EOF
# hello nameserver hello
nameserver 4.4.4.4
EOF
) 172.17.42.1)
    local expected=' -recursor "4.4.4.4"'
    [[ "$result" == "$expected" ]] || $T_fail "expected=\'$expected\' but actual=\'$result\'"
}


T_consulRecursorTwoValid() {
    result=$(consul-recursors <(cat <<EOF
nameserver 4.4.4.4
nameserver 1.1.1.1
EOF
) 172.17.42.1)

    local expected=' -recursor "4.4.4.4" -recursor "1.1.1.1"'
    [[ "$result" == "$expected" ]] || $T_fail "expected=\'$expected\' but actual=\'$result\'"
}


T_consulRecursorOneValidBridgeShouldbeExcluded() {
    result=$(consul-recursors <(cat <<EOF
nameserver 1.2.3.4
nameserver 172.17.42.1
nameserver 1.1.1.1
EOF
) 172.17.42.1)

    local expected=' -recursor "1.2.3.4" -recursor "1.1.1.1"'
    [[ "$result" == "$expected" ]] || $T_fail "expected=\'$expected\' but actual=\'$result\'"
}

T_consulRecursorOneValidBridgeAndDockerIpShouldbeExcluded() {
    result=$(consul-recursors <(cat <<EOF
nameserver 1.2.3.4
nameserver 172.17.42.1
nameserver 192.168.59.103
nameserver 1.1.1.1
EOF
) 172.17.42.1 192.168.59.103)

    local expected=' -recursor "1.2.3.4" -recursor "1.1.1.1"'
    [[ "$result" == "$expected" ]] || $T_fail "expected=\'$expected\' but actual=\'$result\'"
}

T_consulRecursorWithIPV6Address() {
    result=$(consul-recursors <(cat <<EOF
domain local
nameserver 2a02:ab88:42:3f00:20b:ff:fe00:add0
nameserver 192.168.0.1
EOF
) 172.17.42.1 192.168.59.103)

    local expected=' -recursor "[2a02:ab88:42:3f00:20b:ff:fe00:add0]" -recursor "192.168.0.1"'
    [[ "$result" == "$expected" ]] || $T_fail "expected=\'$expected\' but actual=\'$result\'"
}

