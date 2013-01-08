var WebcamUpload;

if (WebcamUpload == undefined) {
	WebcamUpload = function (settings) {
		this.initWebcamUpload(settings);
	};
}

/**
 * Init function
 */
WebcamUpload.prototype.initWebcamUpload = function (settings) {
	try {
		this.customSettings = {};	// A container where developers can place their own settings associated with this instance.
		this.settings = settings;
		this.eventQueue = [];
		this.movieName = "WebcamUpload_" + WebcamUpload.movieCount++;
		this.movieElement = null;

		// Setup global control tracking
		WebcamUpload.instances[this.movieName] = this;

		// Load the settings.  Load the Flash movie.
		this.initSettings();
		this.loadFlash();
		this.displayDebugInfo();
	} catch (ex) {
		delete WebcamUpload.instances[this.movieName];
		throw ex;
	}
};

WebcamUpload.instances = {};
WebcamUpload.movieCount = 0;
WebcamUpload.version = "0.1.0";
WebcamUpload.WINDOW_MODE = {
	WINDOW : "window",
	TRANSPARENT : "transparent",
	OPAQUE : "opaque"
};

//Private: takes a URL, determines if it is relative and converts to an absolute URL
//using the current site. Only processes the URL if it can, otherwise returns the URL untouched
WebcamUpload.completeURL = function(url) {
	if (typeof(url) !== "string" || url.match(/^https?:\/\//i) || url.match(/^\//)) {
		return url;
	}
	
	var currentURL = window.location.protocol + "//" + window.location.hostname + (window.location.port ? ":" + window.location.port : "");
	
	var indexSlash = window.location.pathname.lastIndexOf("/");
	if (indexSlash <= 0) {
		path = "/";
	} else {
		path = window.location.pathname.substr(0, indexSlash) + "/";
	}
	
	return /*currentURL +*/ path + url;
	
};

/* ******************** */
/* Instance Members  */
/* ******************** */

// Private: initSettings ensures that all the
// settings are set, getting a default value if one was not assigned.
WebcamUpload.prototype.initSettings = function () {
	this.ensureDefault = function (settingName, defaultValue) {
		this.settings[settingName] = (this.settings[settingName] == undefined) ? defaultValue : this.settings[settingName];
	};
	
	// Upload backend settings
	this.ensureDefault("upload_url", "");
	this.ensureDefault("preserve_relative_urls", false);
	this.ensureDefault("file_post_name", "Filedata");
	this.ensureDefault("document_name", "video.flv");
	this.ensureDefault("post_params", {});
	this.ensureDefault("use_query_string", false);
	this.ensureDefault("requeue_on_error", false);
	this.ensureDefault("http_success", [200]);
	this.ensureDefault("assume_success_timeout", 0);

	// Flash Settings
	this.ensureDefault("flash_url", "webcamupload.swf");
	this.ensureDefault("prevent_swf_caching", true);
	this.ensureDefault("webcam_placeholder_id", "");
	this.ensureDefault("webcam_placeholder", null);
	this.ensureDefault("webcam_width", '100%');
	this.ensureDefault("webcam_height", '100%');
	this.ensureDefault("webcam_window_mode", WebcamUpload.WINDOW_MODE.WINDOW);
	this.ensureDefault("has_audio", true);
	this.ensureDefault("video_width", 320);
	this.ensureDefault("video_height", 240);
	this.ensureDefault("flv_framerate", 15);
	this.ensureDefault("record_max_time", 10);
	
	// Debug Settings
	this.ensureDefault("debug", false);
	this.settings.debug_enabled = this.settings.debug;	// Here to maintain v2 API
	
	// Event Handlers
	//this.settings.return_upload_start_handler = this.returnUploadStart;
	this.ensureDefault("webcamupload_loaded_handler", null);

	this.ensureDefault("record_start_handler", null);
	this.ensureDefault("record_progress_handler", null);
	this.ensureDefault("record_stop_handler", null);
	this.ensureDefault("record_cancel_handler", null);
	this.ensureDefault("encode_start_handler", null);
	this.ensureDefault("encode_progress_handler", null);
	this.ensureDefault("encode_stop_handler", null);
	this.ensureDefault("upload_start_handler", null);
	this.ensureDefault("upload_progress_handler", null);
	this.ensureDefault("upload_error_handler", null);
	this.ensureDefault("upload_success_handler", null);
	this.ensureDefault("upload_complete_handler", null);
	this.ensureDefault("webcam_error_handler", null);
	
	this.ensureDefault("debug_handler", this.debugMessage);

	this.ensureDefault("custom_settings", {});

	// Other settings
	this.customSettings = this.settings.custom_settings;
	
	// Update the flash url if needed
	if (!!this.settings.prevent_swf_caching) {
		this.settings.flash_url = this.settings.flash_url + (this.settings.flash_url.indexOf("?") < 0 ? "?" : "&") + "preventswfcaching=" + new Date().getTime();
	}
	
	if (!this.settings.preserve_relative_urls) {
		this.settings.upload_url = WebcamUpload.completeURL(this.settings.upload_url);
		this.settings.button_image_url = WebcamUpload.completeURL(this.settings.button_image_url);
	}
	
	delete this.ensureDefault;
};

//Private: loadFlash replaces the button_placeholder element with the flash movie.
WebcamUpload.prototype.loadFlash = function () {
	var targetElement, tempParent;

	// Make sure an element with the ID we are going to use doesn't already exist
	if (document.getElementById(this.movieName) !== null) {
		throw "ID " + this.movieName + " is already in use. The Flash Object could not be added";
	}

	// Get the element where we will be placing the flash movie
	targetElement = document.getElementById(this.settings.webcam_placeholder_id) || this.settings.webcam_placeholder;

	if (targetElement == undefined) {
		throw "Could not find the placeholder element: " + this.settings.placeholder_id;
	}

	// Append the container and load the flash
	tempParent = document.createElement("div");
	tempParent.innerHTML = this.getFlashHTML();	// Using innerHTML is non-standard but the only sensible way to dynamically add Flash in IE (and maybe other browsers)
	targetElement.parentNode.replaceChild(tempParent.firstChild, targetElement);

	// Fix IE Flash/Form bug
	if (window[this.movieName] == undefined) {
		window[this.movieName] = this.getMovieElement();
	}
	
};

//Private: getFlashHTML generates the object tag needed to embed the flash in to the document
WebcamUpload.prototype.getFlashHTML = function () {
	// Flash Satay object syntax: http://www.alistapart.com/articles/flashsatay
	return ['<object id="', this.movieName, '" type="application/x-shockwave-flash" data="', this.settings.flash_url, '" width="', this.settings.webcam_width, '" height="', this.settings.webcam_height, '" class="webcamupload">',
				'<param name="wmode" value="', this.settings.webcam_window_mode, '" />',
				'<param name="movie" value="', this.settings.flash_url, '" />',
				'<param name="quality" value="high" />',
				'<param name="menu" value="false" />',
				'<param name="allowScriptAccess" value="always" />',
				'<param name="flashvars" value="' + this.getFlashVars() + '" />',
				'</object>'].join("");
};

//Private: getFlashHTML generates the object tag needed to embed the flash in to the document
WebcamUpload.prototype.getState = function () {
	return this.callFlash("getState");
};

//Private: getFlashVars builds the parameter string that will be passed
//to flash in the flashvars param.
WebcamUpload.prototype.getFlashVars = function () {
	// Build a string from the post param object
	var paramString = this.buildParamString();
	var httpSuccessString = this.settings.http_success.join(",");
	
	// Build the parameter string
	return ["movieName=", encodeURIComponent(this.movieName),
			"&amp;uploadURL=", encodeURIComponent(this.settings.upload_url),
			"&amp;useQueryString=", encodeURIComponent(this.settings.use_query_string),
			"&amp;httpSuccess=", encodeURIComponent(httpSuccessString),
			"&amp;assumeSuccessTimeout=", encodeURIComponent(this.settings.assume_success_timeout),
			"&amp;params=", encodeURIComponent(paramString),
			"&amp;filePostName=", encodeURIComponent(this.settings.file_post_name),
			"&amp;debugEnabled=", encodeURIComponent(this.settings.debug_enabled),
			"&amp;hasAudio=", encodeURIComponent(this.settings.has_audio),
			"&amp;videoWidth=", encodeURIComponent(this.settings.video_width),
			"&amp;videoHeight=", encodeURIComponent(this.settings.video_height),
			"&amp;flvFrameRate=", encodeURIComponent(this.settings.flv_framerate),
			"&amp;recordMaxTime=", encodeURIComponent(this.settings.record_max_time),
			"&amp;documentName=", encodeURIComponent(this.settings.document_name)
		].join("");
};

//Public: getMovieElement retrieves the DOM reference to the Flash element added by WebcamUpload
//The element is cached after the first lookup
WebcamUpload.prototype.getMovieElement = function () {
	if (this.movieElement == undefined) {
		this.movieElement = document.getElementById(this.movieName);
	}

	if (this.movieElement === null) {
		throw "Could not find Flash element";
	}
	
	return this.movieElement;
};

//Private: buildParamString takes the name/value pairs in the post_params setting object
//and joins them up in to a string formatted "name=value&amp;name=value"
WebcamUpload.prototype.buildParamString = function () {
	var postParams = this.settings.post_params; 
	var paramStringPairs = [];

	if (typeof(postParams) === "object") {
		for (var name in postParams) {
			if (postParams.hasOwnProperty(name)) {
				paramStringPairs.push(encodeURIComponent(name.toString()) + "=" + encodeURIComponent(postParams[name].toString()));
			}
		}
	}

	return paramStringPairs.join("&amp;");
};

//Private: buildParamString takes the name/value pairs in the post_params setting object
//and joins them up in to a string formatted "name=value&amp;name=value"
WebcamUpload.prototype.buildParamString = function () {
	var postParams = this.settings.post_params; 
	var paramStringPairs = [];

	if (typeof(postParams) === "object") {
		for (var name in postParams) {
			if (postParams.hasOwnProperty(name)) {
				paramStringPairs.push(encodeURIComponent(name.toString()) + "=" + encodeURIComponent(postParams[name].toString()));
			}
		}
	}

	return paramStringPairs.join("&amp;");
};

//Public: Used to remove a WebcamUpload instance from the page. This method strives to remove
//all references to the SWF, and other objects so memory is properly freed.
//Returns true if everything was destroyed. Returns a false if a failure occurs leaving WebcamUpload in an inconsistant state.
//Credits: Major improvements provided by steffen
WebcamUpload.prototype.destroy = function () {
	try {
		// Make sure Flash is done before we try to remove it
		this.cancelUpload(null, false);
		

		// Remove the WebcamUpload DOM nodes
		var movieElement = null;
		movieElement = this.getMovieElement();
		
		if (movieElement && typeof(movieElement.CallFunction) === "unknown") { // We only want to do this in IE
			// Loop through all the movie's properties and remove all function references (DOM/JS IE 6/7 memory leak workaround)
			for (var i in movieElement) {
				try {
					if (typeof(movieElement[i]) === "function") {
						movieElement[i] = null;
					}
				} catch (ex1) {}
			}

			// Remove the Movie Element from the page
			try {
				movieElement.parentNode.removeChild(movieElement);
			} catch (ex) {}
		}
		
		// Remove IE form fix reference
		window[this.movieName] = null;

		// Destroy other references
		WebcamUpload.instances[this.movieName] = null;
		delete WebcamUpload.instances[this.movieName];

		this.movieElement = null;
		this.settings = null;
		this.customSettings = null;
		this.eventQueue = null;
		this.movieName = null;
		
		
		return true;
	} catch (ex2) {
		return false;
	}
};

// Public: displayDebugInfo prints out settings and configuration
// information about this WebcamUpload instance.
// This function (and any references to it) can be deleted when placing
// WebcamUpload in production.
WebcamUpload.prototype.displayDebugInfo = function () {
	this.debug(
		[
			"---WebcamUpload Instance Info---\n",
			"Version: ", WebcamUpload.version, "\n",
			"Movie Name: ", this.movieName, "\n",
			"Settings:\n",
			"\t", "upload_url:               ", this.settings.upload_url, "\n",
			"\t", "flash_url:                ", this.settings.flash_url, "\n",
			"\t", "use_query_string:         ", this.settings.use_query_string.toString(), "\n",
			"\t", "http_success:             ", this.settings.http_success.join(", "), "\n",
			"\t", "assume_success_timeout:   ", this.settings.assume_success_timeout, "\n",
			"\t", "file_post_name:           ", this.settings.file_post_name, "\n",
			"\t", "post_params:              ", this.settings.post_params.toString(), "\n",
			"\t", "debug:                    ", this.settings.debug.toString(), "\n",
			"\t", "prevent_swf_caching:      ", this.settings.prevent_swf_caching.toString(), "\n",
			"\t", "placeholder_id:		  ", this.settings.webcam_placeholder_id.toString(), "\n",
			"\t", "placeholder:		  ", (this.settings.webcam_placeholder ? "Set" : "Not Set"), "\n",
			"\t", "custom_settings:          ", this.settings.custom_settings.toString(), "\n",
			"Video and audio settings:\n",
			"\t", "document_name:		  ", this.settings.document_name,"\n",
			"\t", "has_audio:		  ", this.settings.has_audio,"\n",
			"\t", "video_width:		  ", this.settings.video_width,"\n",
			"\t", "video_height:		  ", this.settings.video_height,"\n",
			"\t", "flv_framerate:		  ", this.settings.flv_framerate,"\n",
			"\t", "record_max_time:		  ", this.settings.record_max_time,"\n",
			"Event Handlers:\n",
			"\t", "webcamupload_loaded_handler assigned:  ", (typeof this.settings.webcamupload_loaded_handler === "function").toString(), "\n",
			"\t", "record_start_handler assigned:      ", (typeof this.settings.record_start_handler === "function").toString(), "\n",
			"\t", "record_progress_handler assigned:       ", (typeof this.settings.record_progress_handler === "function").toString(), "\n",
			"\t", "record_stop_handler assigned:       ", (typeof this.settings.record_stop_handler === "function").toString(), "\n",
			"\t", "record_cancel_handler assigned:       ", (typeof this.settings.record_cancel_handler === "function").toString(), "\n",
			"\t", "encode_start_handler assigned:      ", (typeof this.settings.encode_start_handler === "function").toString(), "\n",
			"\t", "encode_progress_handler assigned:       ", (typeof this.settings.encode_progress_handler === "function").toString(), "\n",
			"\t", "encode_stop_handler assigned:       ", (typeof this.settings.encode_stop_handler === "function").toString(), "\n",
			"\t", "upload_start_handler assigned:      ", (typeof this.settings.upload_start_handler === "function").toString(), "\n",
			"\t", "upload_progress_handler assigned:   ", (typeof this.settings.upload_progress_handler === "function").toString(), "\n",
			"\t", "upload_error_handler assigned:      ", (typeof this.settings.upload_error_handler === "function").toString(), "\n",
			"\t", "upload_success_handler assigned:    ", (typeof this.settings.upload_success_handler === "function").toString(), "\n",
			"\t", "upload_complete_handler assigned:   ", (typeof this.settings.upload_complete_handler === "function").toString(), "\n",
			"\t", "webcam_error_handler assigned:   ", (typeof this.settings.webcam_error_handler === "function").toString(), "\n",
			"\t", "debug_handler assigned:             ", (typeof this.settings.debug_handler === "function").toString(), "\n"
		].join("")
	);
};

//Private: callFlash handles function calls made to the Flash element.
//Calls are made with a setTimeout for some functions to work around
//bugs in the ExternalInterface library.
WebcamUpload.prototype.callFlash = function (functionName, argumentArray) {
	argumentArray = argumentArray || [];
	
	var movieElement = this.getMovieElement();
	var returnValue, returnString;

	// Flash's method if calling ExternalInterface methods (code adapted from MooTools).
	try {
		returnString = movieElement.CallFunction('<invoke name="' + functionName + '" returntype="javascript">' + __flash__argumentsToXML(argumentArray, 0) + '</invoke>');
		returnValue = eval(returnString);
	} catch (ex) {
		throw "Call to " + functionName + " failed";
	}
	
	// Unescape file post param values
	if (returnValue != undefined && typeof returnValue.post === "object") {
		returnValue = this.unescapeFilePostParams(returnValue);
	}

	return returnValue;
};

//Public: startRecord begins recording.
WebcamUpload.prototype.startRecord = function (name) {
	this.callFlash("StartRecord",[name]);
};

//Public: stopRecord stops the recording and launch the encoding.
WebcamUpload.prototype.stopRecord = function () {
	this.callFlash("StopRecord");
};

//Public: stopRecord stops the recording and launch the encoding.
WebcamUpload.prototype.cancelRecord = function () {
	this.callFlash("CancelRecord");
};

WebcamUpload.prototype.uploadStart = function (file) {
	file = this.unescapeFilePostParams(file);
	this.queueEvent("upload_start_handler", file);
};

WebcamUpload.prototype.uploadProgress = function (file, bytesComplete, bytesTotal) {
	file = this.unescapeFilePostParams(file);
	this.queueEvent("upload_progress_handler", [file, bytesComplete, bytesTotal]);
};

WebcamUpload.prototype.uploadError = function (file, errorCode, message) {
	file = this.unescapeFilePostParams(file);
	this.queueEvent("upload_error_handler", [file, errorCode, message]);
};

WebcamUpload.prototype.uploadSuccess = function (file, serverData, responseReceived) {
	file = this.unescapeFilePostParams(file);
	this.queueEvent("upload_success_handler", [file, serverData, responseReceived]);
};

WebcamUpload.prototype.uploadComplete = function (file) {
	file = this.unescapeFilePostParams(file);
	this.queueEvent("upload_complete_handler", file);
};

WebcamUpload.prototype.webcamError = function () {
	this.queueEvent("webcam_error_handler");
};

// Public: setHTTPSuccess changes the http_success setting
WebcamUpload.prototype.setHTTPSuccess = function (http_status_codes) {
	if (typeof http_status_codes === "string") {
		http_status_codes = http_status_codes.replace(" ", "").split(",");
	}
	
	this.settings.http_success = http_status_codes;
	this.callFlash("SetHTTPSuccess", [http_status_codes]);
};

/* Called by WebcamUpload JavaScript and Flash functions when debug is enabled. By default it writes messages to the
   internal debug console. You can override this event and have messages written where you want. */
WebcamUpload.prototype.debug = function (message) {
	this.queueEvent("debug_handler", message);
};

/* *******************************
	Flash Event Interfaces
	These functions are used by Flash to trigger the various
	events.
	
	All these functions a Private.
	
	Because the ExternalInterface library is buggy the event calls
	are added to a queue and the queue then executed by a setTimeout.
	This ensures that events are executed in a determinate order and that
	the ExternalInterface bugs are avoided.
******************************* */

WebcamUpload.prototype.queueEvent = function (handlerName, argumentArray) {
	// Warning: Don't call this.debug inside here or you'll create an infinite loop
	
	if (argumentArray == undefined) {
		argumentArray = [];
	} else if (!(argumentArray instanceof Array)) {
		argumentArray = [argumentArray];
	}
	
	var self = this;
	if (typeof this.settings[handlerName] === "function") {
		// Queue the event
		this.eventQueue.push(function () {
			this.settings[handlerName].apply(this, argumentArray);
		});
		
		// Execute the next queued event
		setTimeout(function () {
			self.executeNextEvent();
		}, 0);
		
	} else if (this.settings[handlerName] !== null) {
		throw "Event handler " + handlerName + " is unknown or is not a function";
	}
};

// Private: Causes the next event in the queue to be executed.  Since events are queued using a setTimeout
// we must queue them in order to garentee that they are executed in order.
WebcamUpload.prototype.executeNextEvent = function () {
	// Warning: Don't call this.debug inside here or you'll create an infinite loop

	var  f = this.eventQueue ? this.eventQueue.shift() : null;
	if (typeof(f) === "function") {
		f.apply(this);
	}
};

// Private: unescapeFileParams is part of a workaround for a flash bug where objects passed through ExternalInterface cannot have
// properties that contain characters that are not valid for JavaScript identifiers. To work around this
// the Flash Component escapes the parameter names and we must unescape again before passing them along.
WebcamUpload.prototype.unescapeFilePostParams = function (file) {
	var reg = /[$]([0-9a-f]{4})/i;
	var unescapedPost = {};
	var uk;

	if (file != undefined) {
		for (var k in file.post) {
			if (file.post.hasOwnProperty(k)) {
				uk = k;
				var match;
				while ((match = reg.exec(uk)) !== null) {
					uk = uk.replace(match[0], String.fromCharCode(parseInt("0x" + match[1], 16)));
				}
				unescapedPost[uk] = file.post[k];
			}
		}

		file.post = unescapedPost;
	}

	return file;
};

// Private: Called by Flash to see if JS can call in to Flash (test if External Interface is working)
WebcamUpload.prototype.testExternalInterface = function () {
	try {
		return this.callFlash("TestExternalInterface");
	} catch (ex) {
		return false;
	}
};

//Private: This event is called by Flash when it has finished loading. Don't modify this.
//Use the webcamupload_loaded_handler event setting to execute custom code when WebcamUpload has loaded.
WebcamUpload.prototype.flashReady = function () {
	// Check that the movie element is loaded correctly with its ExternalInterface methods defined
	var movieElement = this.getMovieElement();

	if (!movieElement) {
		this.debug("Flash called back ready but the flash movie can't be found.");
		return;
	}

	this.queueEvent("webcamupload_loaded_handler");
	
	this.cleanUp(movieElement);
};

/* Called when we start recording. */
WebcamUpload.prototype.recordStart = function () {
	this.queueEvent("record_start_handler");
};

/* Called when we stop recording. */
WebcamUpload.prototype.recordStop = function (frames_recorded,seconds_recorded) {
	this.queueEvent("record_stop_handler",[frames_recorded,seconds_recorded]);
};

/* Called when we stop recording. */
WebcamUpload.prototype.recordStopForce = function (frames_recorded,seconds_recorded) {
	alert('Record forced to stop '+seconds_recorded);
	this.queueEvent("record_stop_forced_handler",[frames_recorded,seconds_recorded]);
};

/* Called when progressing records. */
WebcamUpload.prototype.recordProgress = function (frames_recorded,seconds_recorded) {
	this.queueEvent("record_progress_handler",[frames_recorded,seconds_recorded]);
};

/* Called when we cancel recording. */
WebcamUpload.prototype.recordCancel = function () {
	this.queueEvent("record_cancel_handler");
};

/* Called when a media begins to be encoded (in FLV). */
WebcamUpload.prototype.encodeStart = function (total_frames) {
	this.queueEvent("encode_start_handler",[total_frames]);
};

/* Called when a media is progressing being encoded (in FLV). */
WebcamUpload.prototype.encodeProgress = function (current_frame, total_frames, size) {
	this.queueEvent("encode_progress_handler",[current_frame, total_frames, size]);
};

/* Called when a file is successfully added to the queue. */
WebcamUpload.prototype.encodeStop = function (total_frames,size) {
	this.queueEvent("encode_stop_handler",[total_frames, size]);
};

/* **********************************
	Debug Console
	The debug console is a self contained, in page location
	for debug message to be sent.  The Debug Console adds
	itself to the body if necessary.

	The console is automatically scrolled as messages appear.
	
	If you are using your own debug handler or when you deploy to production and
	have debug disabled you can remove these functions to reduce the file size
	and complexity.
********************************** */
   
// Private: debugMessage is the default debug_handler.  If you want to print debug messages
// call the debug() function.  When overriding the function your own function should
// check to see if the debug setting is true before outputting debug information.
WebcamUpload.prototype.debugMessage = function (message) {
	if (this.settings.debug) {
		var exceptionMessage, exceptionValues = [];

		// Check for an exception object and print it nicely
		if (typeof message === "object" && typeof message.name === "string" && typeof message.message === "string") {
			for (var key in message) {
				if (message.hasOwnProperty(key)) {
					exceptionValues.push(key + ": " + message[key]);
				}
			}
			exceptionMessage = exceptionValues.join("\n") || "";
			exceptionValues = exceptionMessage.split("\n");
			exceptionMessage = "EXCEPTION: " + exceptionValues.join("\nEXCEPTION: ");
			WebcamUpload.Console.writeLine(exceptionMessage);
		} else {
			WebcamUpload.Console.writeLine(message);
		}
	}
};

WebcamUpload.Console = {};
WebcamUpload.Console.writeLine = function (message) {
	try {
		if(window.console && typeof(console.log) == 'function')
			console.log(message);
		else{
			var debugconsole, documentForm;
			debugconsole = document.getElementById("WebcamUpload_Console");
			if (!debugconsole) {
				documentForm = document.createElement("form");
				document.getElementsByTagName("body")[0].appendChild(documentForm);
	
				debugconsole = document.createElement("textarea");
				debugconsole.id = "WebcamUpload_Console";
				debugconsole.style.fontFamily = "monospace";
				debugconsole.setAttribute("wrap", "off");
				debugconsole.wrap = "off";
				debugconsole.style.overflow = "auto";
				debugconsole.style.width = "700px";
				debugconsole.style.height = "350px";
				debugconsole.style.margin = "5px";
				documentForm.appendChild(console);
			}
	
			debugconsole.value += message + "\n";
	
			debugconsole.scrollTop = debugconsole.scrollHeight - debugconsole.clientHeight;
		}
	} catch (ex) {
		alert("Exception: " + ex.name + " Message: " + ex.message);
	}
};