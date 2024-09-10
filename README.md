# cgi_command

This library and CGI script is designed to execute arbitrary commands via CGI.

It is designed to provide simple shell script-like administration/automation
functionality for the browser with a dead-simple bash CGI-based backend.

The JavaScript part of this library makes common operations
(such as getting a complete response from a command, streaming a response,
uploading/downloading files from the server, etc.)
easy, and the CGI script serves as the backend for this.

The CGI script is designed to be as flexible as possible,
and can set any response headers, including content-type, allows setting
environment variables and changing directories before executing,
supports various encodings(such as an unmodified, event stream, base64),
and allows all HTTP methods(parameters are always URL-encoded).



# CgiCommand.js

This JavaScript library contains the base functionality for generating URLs and
executing requests to the CGI script.


## `CgiCommand` Constructor

The constructor arguments are put into the properties, and never used directly.

```
CgiCommand(command, base_url=CGI_BACKEND, encoding="none", headers=[], env=[], content_type="text/plain", merge_stderr=true)
```


## Properties

 * command
 * base_url
 * encoding
 * headers
 * env
 * merge_stderr
 * content_type


## Methods

All methods make use of properties, not constructor arguments directly.

 * get_url()
  - Return the URL base on the current properties
 * xhr_sync(method="GET", body)
  - Perform a synchronous XHR, and return the request
 * xhr(method="GET", body, resp_cb, progress_cb)
  - Perform an asynchronous XHR, and register the callback(returns the request immediately)
 * stream(open_cb, data_cb, ret_cb)
  - Start streaming events using the Server-Sent Events/EventSource() mechanism.


# cgi-bin/cgi_command.sh

This is the server-side CGI script that runs the command and encodes the output.


## !!! WARNING !!!

Warning: Leaving this CGI script runnable unprotected is obviously very dangerous!

It should almost always be protected by some sort of authentication.
Giving access to this script should be treated the same as giving access to
a shell belonging to the user that runs the CGI script.


## Requirements

This CGI script just requires basic shell tools(bash, coreutils), and a
CGI capable webserver.

For testing, it is convenient to use the BusyBox httpd server.
An example configuration `busybox_httpd.conf` file is provided.

You can start a test instance like this(from this directory):

```
busybox httpd -v -f -p 127.0.0.1:8080 -c busybox_httpd.conf
```

## nginx

If you want to use nginx to host this script, you can use fcgiwrapd to listen
for fcgi requests on a unix socket, and have that run the CGI script.
This makes it easy to export the shell as another user as well
(www-data probably has shell access disabled). Make sure fcgiwrapd has multiple
processes preforked.

You need to make sure to disable buffering as well, or you can't properly
stream the responses using the server-sent events/EventSource mechanism.

See the included `nginx.conf` for an example.


## QUERY_STRING parameters

Supported parameters in the QUERY_STRING. Some options can be specified multiple times.

 * `cmd` - command to run(required, can be specified multiple times to supply arguments)
 * `encoding` - One of "eventstream_bytes", "eventstream_lines", "base64" or "none"(required)
 * `header` - A header to include(complete "Header: value" line, can be specified multiple times)
 * `env` - Export an environment variable(in exports "ENV_VAR=value" format)
 * `cwd` - Change working directory before running command
 * `content_type` - If set, respond with the specified Content-Type. Defaults to text/plain
 * `merge_stderr` - If set to true, stderr is merged with stdout



# ShellUtils.js

This JavaScript library contains shell related utillity functions.

These basic utillity functions use synchronous XHRs and are intended to provide
simple shell script-like administration/automation functionality for the browser.


## escape_shell(str) 

escape shell special characters in str.


## `ShellUtils` Constructor

You need to provide the URL to the `cgi_command.sh` script as the only parameter.

```
ShellUtils(base_url)
```


## Properties

The only property of a ShellUtils instance is `base_url`, which is used for
creating the requests.


## Methods

All methods use synchronous XHRs.

 * run(cmd, body)
  - Runs the command(array of strings), optionally with body sent to stdin
 * run_script(script_str)
  - Runs the script_str by providing it on stdin to bash.
 * upload_to_path(data, path)
  - Upload the specified data(string) to path
 * get_file_url(path, content_type="application/octet-stream")
  - Get a URL to this file on the server(`cat $path` with content_type)
 * get_env()
  - Get the parsed environment the CGI script runs with(`printenv`)
