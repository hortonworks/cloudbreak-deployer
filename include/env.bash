
declare -a _env

env-import() {
	declare var="$1" default="$2" pattern="$3" patterntext="$4"
	if [[ -z "${!var+x}" ]]; then
		if [[ -z "${2+x}" ]]; then
			echo "!! Imported variable $var must be set in profile or environment." | red
			_exit 2
		else
			export $var="$default"
		fi
	fi
	if [[ $pattern ]] && [[ ${!var} == $pattern ]]; then
		echo "!! Imported variable $var contains $patterntext." | red
		_exit 3
	fi
	_env+=($var)
}

env-show() {
	declare desc="Shows relevant environment variables, in human readable format"
    
    # TODO cloudbreak config shouldnt be called here ...
    cloudbreak-config
    migrate-config
	local longest=0
	for var in "${_env[@]}"; do
		if [[ "${#var}" -gt "$longest" ]]; then
			longest="${#var}"
		fi
	done
	for var in "${_env[@]}"; do
		printf "%-${longest}s = %s\n" "$var" "${!var}"
	done
}

env-export() {
	declare desc="Shows relevant environment variables, in a machine friendly format."
    
    # TODO cloudbreak config shouldnt be called here ...
    cloudbreak-config
    migrate-config
	for var in "${_env[@]}"; do
		printf 'export %s=%s\n' "$var" "${!var}"
	done
}

