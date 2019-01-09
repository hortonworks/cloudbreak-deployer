util-generate-ldap-mapping() {
  declare desc="Generates an SQL script to map LDAP/AD groups to Cloudbreak defined OAuth2 scopes. Useful if you want to make changes in the mapping."
  debug $desc

  local mapping_file="mapping.sql"
  generate-ldap-mapping "$1" "$mapping_file"
  info "Group mapping file has been created: $mapping_file"
  info "To apply the $mapping_file please run the following command: docker exec cbreak_$COMMON_DB_1 psql -U postgres -d uaadb -c \"\$(cat $mapping_file)\""
  info "To clean up the group mapping please run the following command: docker exec cbreak_$COMMON_DB_1 psql -U postgres -d uaadb -c \"delete from external_group_mapping\""
  info "Note: you must log out and log back in with your LDAP/AD users after the mapping change"
}

util-execute-ldap-mapping() {
  declare desc="Generates and automatically applies the changes in identity to map LDAP/AD groups to Cloudbreak defined OAuth2 scopes"
  debug $desc

  exit-on-remote-database uaadb

  local mapping_file="$TEMP_DIR/mapping-delme.yml"
  generate-ldap-mapping "$1" "$mapping_file"
  info "Applying LDAP/AD mapping"
  docker exec cbreak_${COMMON_DB}_1 psql -U postgres -d uaadb -c "$(cat $mapping_file)"
  rm -f "$mapping_file"
  info "Successfully applied LDAP/AD mapping"
  info "Note: you must log out and log back in with your LDAP/AD users after the mapping change"
}

util-delete-ldap-mapping() {
  declare desc="Removes all the LDAP/AD group mappings to OAuth2 scopes"
  debug $desc

  exit-on-remote-database uaadb

  local container=$(docker ps | grep cbreak_${COMMON_DB}_ | cut -d" " -f 1)
    if ! [[ "$container" ]]; then
        error "Cloudbreak isn't running, please start it"
        _exit 1
    fi

  info "Remove LDAP/AD mappings"
  docker exec cbreak_${COMMON_DB}_1 psql -U postgres -d uaadb -c "delete from external_group_mapping"
  info "Successfully removed LDAP/AD mappings"
  info "Note: you must log out and log back in with your LDAP/AD users after the mapping change"
}

generate-ldap-mapping() {
  exit-on-remote-database uaadb
  
 if [[ -z "$1" ]]; then
    error "LDAP/AD group DN parameter must be provided (e.g: CN=cloudbreak,CN=Users,DC=ad,DC=mycompany,DC=com)"
    _exit 1
  fi
  local group="$1"
  local mapping_file=${2:-mapping.sql}

  local container=$(docker ps | grep cbreak_${COMMON_DB}_ | cut -d" " -f 1)
    if ! [[ "$container" ]]; then
        error "Cloudbreak isn't running, please start it"
        _exit 1
    fi

  local scopes=$(docker exec $container psql -U postgres -d uaadb -c "select displayname from groups where displayname like 'cloudbreak%' or displayname like 'periscope%' or displayname='sequenceiq.cloudbreak.user';" | tail -n +3 | grep -v rows)
  rm -f ${mapping_file}
  for scope in ${scopes}; do
    local line="INSERT INTO external_group_mapping (group_id, external_group, added, origin) VALUES ((select id from groups where displayname='$scope'), '$group', '2016-09-30 19:28:24.255', 'ldap');"
    echo $line >> ${mapping_file}
  done
}