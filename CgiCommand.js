let CGI_BACKEND = "/cgi-bin/cgi_command.sh"

// library for using the functionality from the cgi-bin/cgi_command.sh script from javascript.
// supports encoding the URL parameters, sending XHRs, and streaming responses using EventSource
function CgiCommand(command, base_url=CGI_BACKEND, encoding="none", headers=[], env=[], content_type="text/plain", merge_stderr=true) {
	this.command = command
	this.base_url = base_url
	this.encoding = encoding
	this.headers = headers
	this.env = env
	this.merge_stderr = merge_stderr
	this.content_type = content_type

	// encode the current state as a URL
	this.get_url = () => {
		let url_args = []
		url_args.push(this.command.map((e) => "cmd=" + encodeURIComponent(e)).join("&"))
		url_args.push("encoding="+encodeURIComponent(this.encoding))
		url_args.push("merge_stderr="+encodeURIComponent(this.merge_stderr))
		if (this.encoding == "eventstream_bytes" || this.encoding == "eventstream_lines") {
			url_args.push("content_type="+encodeURIComponent("text/event-stream"))
			url_args.push("header="+encodeURIComponent("X-Accel-Buffering: no"))
			url_args.push("header="+encodeURIComponent("Cache-Control: no-cache"))
		} else {
			url_args.push("content_type="+encodeURIComponent(this.content_type))
		}
		if (this.headers.length>0) {
			url_args.push(this.headers.map((e) => "header=" + encodeURIComponent(e)).join("&"))
		}
		if (this.env.length>0) {
			url_args.push(this.env.map((e) => "env=" + encodeURIComponent(e)).join("&"))
		}
		return this.base_url + "?" + url_args.join("&")
	}

	// get the complete command response using a synchronous XHR
	this.xhr_sync = (method="GET", body) => {
		let url = this.get_url()
		let req = new XMLHttpRequest()
		req.open(method, url, false)
		req.send(body)
		return req
	}

	// get the complete command response using an asynchronous XHR
	this.xhr = (method="GET", body, resp_cb, progress_cb) => {
		let url = this.get_url()
		let req = new XMLHttpRequest()
		req.onreadystatechange = function() {
			if ((req.readyState == XMLHttpRequest.DONE) && resp_cb) {
				return resp_cb(req.responseText, req)
			}
		}
		req.upload.onprogress = progress_cb
		req.open(method, url, true)
		req.send(body)
		return req
	}

	// create EventSource to stream the command response using the server sent events mechanism
	this.stream = (open_cb, data_cb, ret_cb) => {
		let url = this.get_url()
		let event_source = new EventSource(url)
		event_source.addEventListener("open", () => {
			if (open_cb) { open_cb(); }
		})
		event_source.addEventListener("error", () => {
			event_source.close()
		})
		event_source.addEventListener("stream_line", (e) => {
			if (data_cb) { data_cb(e.data + "\n"); }
		})
		event_source.addEventListener("stream_byte", (e) => {
			let char_code = parseInt(e.data, 16)
			let char = String.fromCharCode(char_code)
			if (data_cb) { data_cb(char, char_code); }
		})
		event_source.addEventListener("return", (e) => {
			if (ret_cb) { ret_cb(parseInt(e.data)); }
		})
		return event_source
	}
}
