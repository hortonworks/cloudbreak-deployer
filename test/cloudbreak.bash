T_checkSedVersion() {
    (sed --version|grep GNU | grep -q '4.2') &>/dev/null || $T_fail "GNU sed 4.2 not found on PATH."
}


