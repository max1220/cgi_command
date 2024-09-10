// escape shell special characters in str
function escape_shell(str) {
	return `'${String(str).replace(/'/g, `'\\''`)}'`
}

// very basic shell utilities making use of CgiCommand
function ShellUtils(base_url) {
	this.base_url = base_url

	// run a single command via a synchronous XHR
	// gets stdin from body(optional), returns stdout of command as string
	this.run = (cmd, body) => {
		let cgi_cmd = new CgiCommand(cmd, this.base_url)
		let req = cgi_cmd.xhr_sync("POST", body)
		console.assert(req.status == 200)
		return req.responseText
	}

	// run a command wrapped in eval
	this.run_eval = (cmd, body) =>
		this.run(["eval", ...cmd], body)

	// run a bash script on the server
	this.run_script = (script_str) =>
		this.run(["bash"], script_str)

	// upload data to the server at path
	this.upload_to_path = (data, path) =>
		this.run_eval(["cat", ">", escape_shell(path)], data)

	// get a URL to read a file
	this.get_file_url = (path, content_type="application/octet-stream") =>
		new CgiCommand(["cat", path], base_url, undefined, undefined, undefined, content_type).get_url()

	// call printenv and parse response
	this.get_env = () => {
		let env = {}
		for (let e of this.run(["printenv"]).matchAll(/^(\w+)=(.*)$/gm)) {
			env[e[1]] = e[2]
		}
		return env
	}
}
