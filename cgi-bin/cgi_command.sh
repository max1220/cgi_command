#!/bin/bash
set -euo pipefail
# cgi_command.sh
# Execute arbitrary commands via CGI, optionally encode the output as event-stream.
# Allows to set the response headers, including content-type,
# and allows setting environment variables for the command.
# Allows all methods, parameters are always URL-encoded(in QUERY_STRING).
#
# !!! WARNING !!!
# Leaving this CGI script runnable unprotected is obviously very dangerous!
# !!! WARNING !!!
# 
# Supported QUERY_STRING options:
#  cmd: command to run(required, can be specified multiple times to supply arguments)
#  encoding: One of "eventstream_bytes", "eventstream_lines", "base64" or "none"(required)
#  header: A header to include(complete "Header: value" line, can be specified multiple times)
#  env: Export an environment variable(in exports "ENV_VAR=value" format)
#  cwd: Change working directory before running command
#  content_type: If set, respond with the specified Content-Type. Defaults to text/plain
#  merge_stderr: If set to true, stderr is merged with stdout before running the command 

# exit with an HTTP status code and message
function exit_with_status_message() {
	printf "Status: %d\nContent-type: text/plain\n\n%s\n" "${1}" "${2}"
	exit
}

# URL-decode stdin to stdout.
# Warning: Doesn't support \000(zero-byte)!
function url_decode() {
	: "${1//+/ }"; printf '%b' "${_//%/\\x}"
}

# encode stdin as event-stream events, line-by-line
function encode_eventstream_lines() {
	while LANG="C" IFS="" read -r line; do
		printf "event: stream_line\ndata: %s\n\n" "${line}"
	done
}

# encode stdin as event-stream events, byte-by-byte
function encode_eventstream_bytes() {
	while LANG="C" IFS="" read -r -d "" -N 1 byte_val; do
		printf "event: stream_byte\ndata: %.2x\n\n" "'${byte_val}"
	done
}

# parse the QUERY_STRING into query_parameter_list(a list of containing keys-value pairs)
IFS="&=" read -ra query_parameter_list <<< "${QUERY_STRING}"
# create the associative array query_parameter_array(from the list of key-value pairs in query_parameter_list)
declare -g -A query_parameter_array
for ((i=0; i<${#query_parameter_list[@]}; i+=2)); do
	key_dec="$(url_decode "${query_parameter_list[i]}")"
	value_dec="$(url_decode "${query_parameter_list[i+1]:-}")"
	query_parameter_array+=(["${key_dec}"]="${value_dec}")
done

# parse the query_parameter_list and query_parameter_array into the argument variables(command_str, command_args, headers)
# parse query_parameter_list and get the command to run and the HTTP headers to include
command=()
headers=()
for ((i=0; i<"${#query_parameter_list[@]}"; i=i+2)); do
	if [ "${query_parameter_list[i]}" = "cmd" ]; then
		cmd="$(url_decode "${query_parameter_list[i+1]:-}")"
		command+=("${cmd}")
	elif [ "${query_parameter_list[i]}" = "header" ]; then
		header="$(url_decode "${query_parameter_list[i+1]:-}")"
		headers+=("${header}")
	elif [ "${query_parameter_list[i]}" = "env" ]; then
		env_var="$(url_decode "${query_parameter_list[i+1]:-}")"
		export "${env_var}" || exit_with_status_message "400" "Failed to set environment variable!"
	fi
done

# error if no command was provided
[ "${#command[@]}" = "0" ] && exit_with_status_message "400" "Need to specify command!"

# function to output the response headers.
# called later to support errors using exit_with_status_message
function response_headers() {
	content_type="${query_parameter_array[content_type]:-text/plain}"
	echo "Content-Type: ${content_type}"
	for ((i=0; i<"${#headers[@]}"; i++)); do
		echo "${headers[i]}"
	done
	echo
}

# change working directory if requested
if [ -n "${query_parameter_array[cwd]:-}" ]; then
	cd "${query_parameter_array[cwd]}" || exit_with_status_message "400" "Can't change working directory!"
fi

# redirect stderr to stdout if requested
if [ "${query_parameter_array[merge_stderr]:-}" = "true" ]; then
	exec 2>&1
fi

# run the specified command with the specified encoding function
if [ "${query_parameter_array[encoding]:-}" = "eventstream_bytes" ]; then
	response_headers
	# run the command, encode stdout as hex bytes in the event-stream format
	printf "event: begin\ndata: bytes\n\n"
	"${command[@]}" | encode_eventstream_bytes && return_value="0" || return_value="$?"
	printf "event: return\ndata: %d\n\n" "${return_value}"
elif [ "${query_parameter_array[encoding]:-}" = "eventstream_lines" ]; then
	response_headers
	# run the command, encode stdout as lines in the event-stream format
	printf "event: begin\ndata: lines\n\n"
	"${command[@]}" | encode_eventstream_lines && return_value="0" || return_value="$?"
	printf "event: return\ndata: %d\n\n" "${return_value}"
elif [ "${query_parameter_array[encoding]:-}" = "base64" ]; then
	response_headers
	# run the command, base64-encode the output
	"${command[@]}" | base64
elif [ "${query_parameter_array[encoding]:-}" = "none" ]; then
	response_headers
	# run the command, no encoding
	"${command[@]}"
else
	exit_with_status_message "400" "Invalid encoding requested!"
fi
