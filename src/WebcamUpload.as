package 
{
	import ExternalCall;
	import UploadPostHelper1;
	
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.*;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.Video;
	import flash.net.*;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.clearTimeout;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	
	import leelib.util.flvEncoder.*;

	[SWF(width="320", height="240", frameRate="30")]
    public class WebcamUpload extends Sprite
    {
		// Cause WebcamUpload to start as soon as the movie starts
		public static function main():void
		{
			var WebcamUpload:WebcamUpload = new WebcamUpload();
		}
		
		private const build_number:String = "WEBCAM UPLOAD 0.1.0";
		
		private var _video:Video;
		private var _webcam:Camera;
		private var _micro:MicRecorderUtil;
		private var _netConnection:NetConnection;
		private var _ns:NetStream;
		private var _output:Sprite;
		private var HAS_AUDIO:Boolean = true;
		private var HAS_VIDEO:Boolean = true;
		private var OUTPUT_WIDTH:Number = 320;
		private var OUTPUT_HEIGHT:Number = 240;
		private var RECORD_MAX:Boolean=false;
		private var RECORD_MAX_TIME:Number;

		private var FLV_FRAMERATE:int;

		private var loader:URLLoader;
		internal var Size:int=0;
		internal var documentName:String;
		internal var n:uint=0;
		
		private var _baFlvEncoder:ByteArrayFlvEncoder;
		private var _encodeFrameNum:int;
		
		private var _bitmaps:Array;
		private var _audioData:ByteArray;
		
		private var _startTime:Number;
		private var _timeoutId:Number;
		private var _state:String="waiting";
		
		private var serverDataTimer:Timer = null;
		private var assumeSuccessTimer:Timer = null;
		
		private var restoreExtIntTimer:Timer;
		private var hasCalledFlashReady:Boolean = false;
		private var current_file_item:Object = null;
		private var js_object:Object;
		private var postObject:Object;
		private var file_status:int = 0;
		
		// Callbacks
		private var flashReady_Callback:String;
		private var recordStart_Callback:String;
		private var recordProgress_Callback:String;
		private var recordStop_Callback:String;
		private var recordStopForce_Callback:String;
		private var recordCancel_Callback:String;
		private var encodeStart_Callback:String;
		private var encodeProgress_Callback:String;
		private var encodeStop_Callback:String;
		private var uploadStart_Callback:String;
		private var uploadProgress_Callback:String;
		private var uploadError_Callback:String;
		private var uploadSuccess_Callback:String;
		private var uploadComplete_Callback:String;
		private var webcamError_Callback:String;
		private var debug_Callback:String;
		private var testExternalInterface_Callback:String;
		private var cleanUp_Callback:String;

		// Values passed in from the HTML
		private var movieName:String;
		private var uploadURL:String;
		private var filePostName:String;
		private var uploadPostObject:Object;
		private var useQueryString:Boolean = false;
		private var requeueOnError:Boolean = false;
		private var httpSuccess:Array = [];
		private var assumeSuccessTimeout:Number = 0;
		private var debugEnabled:Boolean;
		
		// Upload Errors
		private var ERROR_CODE_HTTP_ERROR:Number 					= -200;
		private var ERROR_CODE_MISSING_UPLOAD_URL:Number        	= -210;
		private var ERROR_CODE_IO_ERROR:Number 						= -220;
		private var ERROR_CODE_SECURITY_ERROR:Number 				= -230;
		private var ERROR_CODE_UPLOAD_LIMIT_EXCEEDED:Number			= -240;
		private var ERROR_CODE_UPLOAD_FAILED:Number 				= -250;
		private var ERROR_CODE_SPECIFIED_FILE_ID_NOT_FOUND:Number 	= -260;
		private var ERROR_CODE_FILE_VALIDATION_FAILED:Number		= -270;
		private var ERROR_CODE_FILE_CANCELLED:Number				= -280;
		private var ERROR_CODE_UPLOAD_STOPPED:Number				= -290;
		
		public static var FILE_STATUS_QUEUED:int		= -1;
		public static var FILE_STATUS_IN_PROGRESS:int	= -2;
		public static var FILE_STATUS_ERROR:int			= -3;
		public static var FILE_STATUS_SUCCESS:int		= -4;
		public static var FILE_STATUS_CANCELLED:int		= -5;
		public static var FILE_STATUS_NEW:int			= -6;
		
		public function WebcamUpload()
		{
			Security.allowDomain("*");
			
			var self:WebcamUpload = this;
			
			// Get the movie name
			this.movieName = root.loaderInfo.parameters.movieName;
			this.documentName = root.loaderInfo.parameters.documentName;
			
			// **Configure the callbacks**
			// The JavaScript tracks all the instances of WUpload on a page.  We can access the instance
			// associated with this SWF file using the movieName.  Each callback is accessible by making
			// a call directly to it on our instance.  There is no error handling for undefined callback functions.
			// A developer would have to deliberately remove the default functions,set the variable to null, or remove
			// it from the init function.
			this.flashReady_Callback         = "WebcamUpload.instances[\"" + this.movieName + "\"].flashReady";
			this.recordStart_Callback        = "WebcamUpload.instances[\"" + this.movieName + "\"].recordStart";
			this.recordProgress_Callback     = "WebcamUpload.instances[\"" + this.movieName + "\"].recordProgress";
			this.recordStop_Callback         = "WebcamUpload.instances[\"" + this.movieName + "\"].recordStop";
			this.recordStopForce_Callback    = "WebcamUpload.instances[\"" + this.movieName + "\"].recordStopForce";
			this.recordCancel_Callback       = "WebcamUpload.instances[\"" + this.movieName + "\"].recordCancel";
			this.encodeStart_Callback        = "WebcamUpload.instances[\"" + this.movieName + "\"].encodeStart";
			this.encodeProgress_Callback     = "WebcamUpload.instances[\"" + this.movieName + "\"].encodeProgress";
			this.encodeStop_Callback         = "WebcamUpload.instances[\"" + this.movieName + "\"].encodeStop";
			this.uploadStart_Callback        = "WebcamUpload.instances[\"" + this.movieName + "\"].uploadStart";
			this.uploadProgress_Callback     = "WebcamUpload.instances[\"" + this.movieName + "\"].uploadProgress";
			this.uploadError_Callback        = "WebcamUpload.instances[\"" + this.movieName + "\"].uploadError";
			this.uploadSuccess_Callback      = "WebcamUpload.instances[\"" + this.movieName + "\"].uploadSuccess";
			this.webcamError_Callback         = "WebcamUpload.instances[\"" + this.movieName + "\"].webcamError";
			
			this.uploadComplete_Callback     = "WebcamUpload.instances[\"" + this.movieName + "\"].uploadComplete";
			
			this.debug_Callback              = "WebcamUpload.instances[\"" + this.movieName + "\"].debug";
			this.testExternalInterface_Callback = "WebcamUpload.instances[\"" + this.movieName + "\"].testExternalInterface";
			this.cleanUp_Callback              = "WebcamUpload.instances[\"" + this.movieName + "\"].cleanUp";
			
			// Get the Flash Vars
			this.uploadURL = root.loaderInfo.parameters.uploadURL;
			this.filePostName = root.loaderInfo.parameters.filePostName;
			this.loadPostParams(root.loaderInfo.parameters.params);
			
			if (!this.filePostName) {
				this.filePostName = "Filedata";
			}
			
			try {
				this.debugEnabled = root.loaderInfo.parameters.debugEnabled == "true" ? true : false;
			} catch (ex:Object) {
				this.debugEnabled = false;
			}
			
			try {
				this.useQueryString = root.loaderInfo.parameters.useQueryString == "true" ? true : false;
			} catch (ex:Object) {
				this.useQueryString = false;
			}
			
			try {
				this.SetHTTPSuccess(String(root.loaderInfo.parameters.httpSuccess));
			} catch (ex:Object) {
				this.SetHTTPSuccess([]);
			}
			
			try {
				this.SetAssumeSuccessTimeout(Number(root.loaderInfo.parameters.assumeSuccessTimeout));
			} catch (ex:Object) {
				this.SetAssumeSuccessTimeout(0);
			}
			
			try {
				this.HAS_AUDIO = root.loaderInfo.parameters.hasAudio == "true" ? true : false;
			} catch (ex:Object) {
				this.HAS_AUDIO = true;
			}

			try {
				this.HAS_VIDEO = root.loaderInfo.parameters.hasVideo == "true" ? true : false;
			} catch (ex:Object) {
				this.HAS_VIDEO = true;
			}
			
			try {
				this.SetVideoWidth(Number(root.loaderInfo.parameters.videoWidth));
			} catch (ex:Object) {
				this.SetVideoWidth(320);
			}
			
			try {
				this.SetVideoHeight(Number(root.loaderInfo.parameters.videoHeight));
			} catch (ex:Object) {
				this.SetVideoHeight(240);
			}
			
			try {
				this.SetFlvFrameRate(Number(root.loaderInfo.parameters.flvFrameRate));
			} catch (ex:Object) {
				this.SetFlvFrameRate(15);
			}
			
			try {
				this.SetRecordMaxTime(Number(root.loaderInfo.parameters.recordMaxTime));
			} catch (ex:Object) {
				this.SetRecordMaxTime(10);
			}
			
			this.Debug("WebcamUpload Init Complete");
			this.PrintDebugInfo();
			
			if (ExternalCall.Bool(this.testExternalInterface_Callback)) {
				ExternalCall.Simple(this.flashReady_Callback);
				this.hasCalledFlashReady = true;
			}
			
			this.stage.addEventListener(MouseEvent.CLICK, function (event:MouseEvent):void {
				//self.UpdateButtonState();
				self.ButtonClickHandler(event);
			});
			// Start periodically checking the external interface
			var oSelf:WebcamUpload = this;
			this.restoreExtIntTimer = new Timer(1000, 0);
			this.restoreExtIntTimer.addEventListener(TimerEvent.TIMER, function ():void { oSelf.CheckExternalInterface();} );
			this.restoreExtIntTimer.start();
			_video = new Video(stage.stageWidth,stage.stageHeight);
			addChild(_video);
		
			if (Camera.names.length > 0){ 
				this.Debug("User has at least one camera installed.");
				this._webcam = Camera.getCamera();
				this._webcam.addEventListener(StatusEvent.STATUS, webcam_statusHandler); 
				_webcam.setMode(this.OUTPUT_WIDTH, this.OUTPUT_HEIGHT, FLV_FRAMERATE);
				_webcam.setQuality(0,100);
			} 
			else{
				Debug("User has no cameras installed.");
				this._state = 'camera_not_available';
				ExternalCall.Simple(this.webcamError_Callback);
				return;
			}
			
			if(HAS_AUDIO && Microphone.names.length > 0){
				this.Debug("User has at least one microphone.");
				var mic:Microphone = Microphone.getMicrophone();
				mic.setSilenceLevel(0, int.MAX_VALUE);
				mic.gain = 100;
				mic.rate = 44;
				_micro = new MicRecorderUtil(mic);
			}else{
				Debug("User has no microphone installed.");
			}
			
			_netConnection = new NetConnection();
			_netConnection.connect(null);
			_ns = new NetStream(_netConnection);
			_video.attachCamera(_webcam);
			return;
		}
		
		private function TestExternalInterface():Boolean {
			return true;
		}
		
		private function SetHTTPSuccess(http_status_codes:*):void {
			this.httpSuccess = [];
			
			if (typeof http_status_codes === "string") {
				var status_code_strings:Array = http_status_codes.replace(" ", "").split(",");
				for each (var http_status_string:String in status_code_strings) 
				{
					try {
						this.httpSuccess.push(Number(http_status_string));
					} catch (ex:Object) {
						// Ignore errors
						this.Debug("Could not add HTTP Success code: " + http_status_string);
					}
				}
			}
			else if (typeof http_status_codes === "object" && typeof http_status_codes.length === "number") {
				for each (var http_status:* in http_status_codes) 
				{
					try {
						this.Debug("adding: " + http_status);
						this.httpSuccess.push(Number(http_status));
					} catch (ex:Object) {
						this.Debug("Could not add HTTP Success code: " + http_status);
					}
				}
			}
		}
		
		private function SetFlvFrameRate(framerate:Number):void {
			this.FLV_FRAMERATE = framerate;
		}
		
		private function SetVideoWidth(width:Number):void {
			this.OUTPUT_WIDTH = width;
		}
		private function SetVideoHeight(height:Number):void {
			this.OUTPUT_HEIGHT = height;
		}
		private function SetAssumeSuccessTimeout(timeout_seconds:Number):void {
			this.assumeSuccessTimeout = timeout_seconds < 0 ? 0 : timeout_seconds;
		}
		
		private function SetRecordMaxTime(sec:Number):void{
			this.RECORD_MAX = true;
			this.RECORD_MAX_TIME = sec;
		}
		
		private function SetDebugEnabled(debug_enabled:Boolean):void {
			this.debugEnabled = debug_enabled;
		}
		
		// Used to periodically check that the External Interface functions are still working
		private function CheckExternalInterface():void {
			if (!ExternalCall.Bool(this.testExternalInterface_Callback)) {
				this.SetupExternalInterface();
				this.Debug("ExternalInterface reinitialized");
				if (!this.hasCalledFlashReady) {
					ExternalCall.Simple(this.flashReady_Callback);
					this.hasCalledFlashReady = true;
				}
			}
		}
		
		// Les interfaces
		private function SetupExternalInterface():void {
			try {
				ExternalInterface.addCallback("getState", this.getState);
				
				// Enregistrements
				ExternalInterface.addCallback("StartRecord", this.StartRecord);
				ExternalInterface.addCallback("StopRecord", this.StopRecord);
				ExternalInterface.addCallback("CancelRecord", this.CancelRecord);
				
				// Upload
				ExternalInterface.addCallback("StartUpload", this.StartUpload);
				
				ExternalInterface.addCallback("SetUploadURL", this.SetUploadURL);
				ExternalInterface.addCallback("SetPostParams", this.SetPostParams);
				ExternalInterface.addCallback("SetFilePostName", this.SetFilePostName);
				ExternalInterface.addCallback("SetUseQueryString", this.SetUseQueryString);
				ExternalInterface.addCallback("SetHTTPSuccess", this.SetHTTPSuccess);
				ExternalInterface.addCallback("SetAssumeSuccessTimeout", this.SetAssumeSuccessTimeout);
				ExternalInterface.addCallback("SetDebugEnabled", this.SetDebugEnabled);
				
				ExternalInterface.addCallback("TestExternalInterface", this.TestExternalInterface);
				
			} catch (ex:Error) {
				this.Debug("Callbacks where not set: " + ex.message);
				return;
			}
			
			ExternalCall.Simple(this.cleanUp_Callback);
		}
		
		private function SetUploadURL(url:String):void {
			if (typeof(url) !== "undefined" && url !== "") {
				this.uploadURL = url;
			}
		}
		
		private function SetPostParams(post_object:Object):void {
			if (typeof(post_object) !== "undefined" && post_object !== null) {
				this.uploadPostObject = post_object;
			}
		}
		
		private function SetFilePostName(file_post_name:String):void {
			if (file_post_name != "") {
				this.filePostName = file_post_name;
			}
		}
		
		private function SetUseQueryString(use_query_string:Boolean):void {
			this.useQueryString = use_query_string;
		}
		
		private function loadPostParams(param_string:String):void {
			var post_object:Object = {};
			
			if (param_string != null) {
				var name_value_pairs:Array = param_string.split("&amp;");
				
				for (var i:Number = 0; i < name_value_pairs.length; i++) {
					var name_value:String = String(name_value_pairs[i]);
					var index_of_equals:Number = name_value.indexOf("=");
					if (index_of_equals > 0) {
						post_object[decodeURIComponent(name_value.substring(0, index_of_equals))] = decodeURIComponent(name_value.substr(index_of_equals + 1));
					}
				}
			}
			this.uploadPostObject = post_object;
		}
		
		public function AddParam(name:String, value:String):void {
			this.postObject[name] = value;
		}
		
		public function RemoveParam(name:String):void {
			delete this.postObject[name];
		}
		
		public function GetPostObject(escape:Boolean = false):Object {
			if (escape) {
				var escapedPostObject:Object = { };
				for (var k:String in this.postObject) {
					if (this.postObject.hasOwnProperty(k)) {
						var escapedName:String = EscapeParamName(k);
						escapedPostObject[escapedName] = this.postObject[k];
					}
				}
				return escapedPostObject;
			} else {
				return this.postObject;
			}
		}
		
		// Create the simply file object that is passed to the browser
		private function ToJavaScriptObject():Object {
			Debug('tojavascriptobject');
			this.js_object.filestatus = this.file_status;
			this.js_object.post = this.GetPostObject(true);
			
			return this.js_object;
		}
		
		public static function EscapeParamName(name:String):String {
			name = name.replace(/[^a-z0-9_]/gi, EscapeCharacter);
			name = name.replace(/^[0-9]/, EscapeCharacter);
			return name;
		}
		public static function EscapeCharacter():String {
			return "$" + ("0000" + arguments[0].charCodeAt(0).toString(16)).substr(-4, 4);
		}
		
		private function BuildRequest():URLRequest {
			// Create the request object
			var request:URLRequest = new URLRequest();
			request.method = URLRequestMethod.POST;
			
			var file_post:Object = this.GetPostObject();
			
			if (this.useQueryString) {
				var pairs:Array = new Array();
				for (key in this.uploadPostObject) {
					this.Debug("Global URL Item: " + key + "=" + this.uploadPostObject[key]);
					if (this.uploadPostObject.hasOwnProperty(key)) {
						pairs.push(escape(key) + "=" + escape(this.uploadPostObject[key]));
					}
				}
				
				for (key in file_post) {
					this.Debug("File Post Item: " + key + "=" + file_post[key]);
					if (file_post.hasOwnProperty(key)) {
						pairs.push(escape(key) + "=" + escape(file_post[key]));
					}
				}
				
				request.url = this.uploadURL  + (this.uploadURL.indexOf("?") > -1 ? "&" : "?") + pairs.join("&");
			} else {
				var key:String;
				var post:URLVariables = new URLVariables();
				for (key in this.uploadPostObject) {
					this.Debug("Global Post Item: " + key + "=" + this.uploadPostObject[key]);
					if (this.uploadPostObject.hasOwnProperty(key)) {
						post[key] = this.uploadPostObject[key];
					}
				}
				
				for (key in file_post) {
					this.Debug("File Post Item: " + key + "=" + file_post[key]);
					if (file_post.hasOwnProperty(key)) {
						post[key] = file_post[key];
					}
				}
				
				request.url = this.uploadURL;
				request.data = post;
			}
			
			return request;
		}
		
		private function Debug(msg:String):void {
			try {
				if (this.debugEnabled) {
					var lines:Array = msg.split("\n");
					for (var i:Number=0; i < lines.length; i++) {
						lines[i] = "WEBCAM UPLOAD DEBUG: " + lines[i];
					}
					ExternalCall.Debug(this.debug_Callback, lines.join("\n"));
				}
			} catch (ex:Error) {
				// pretend nothing happened
				trace(ex);
			}
		}
		
		private function PrintDebugInfo():void {
			var debug_info:String = "\n----- WEBCAM UPLOAD DEBUG OUTPUT ----\n";
			debug_info += "Build Number:           " + this.build_number + "\n";
			debug_info += "movieName:              " + this.movieName + "\n";
			debug_info += "Upload URL:             " + this.uploadURL + "\n";
			debug_info += "HTTP Success:           " + this.httpSuccess.join(", ") + "\n";
			debug_info += "Post Params:\n";
			for (var key:String in this.uploadPostObject) {
				if (this.uploadPostObject.hasOwnProperty(key)) {
					debug_info += "                        " + key + "=" + this.uploadPostObject[key] + "\n";
				}
			}
			debug_info += "----- END SWF DEBUG OUTPUT ----\n";
			
			this.Debug(debug_info);
		}

		private function ButtonClickHandler(e:MouseEvent):void {
			if(this._state == "encoded"){
				this.StartUpload();
				_baFlvEncoder.kill();
			}
		}
		
		private function webcam_statusHandler(event:StatusEvent):void{
			if(event.code == "Camera.Muted"){
				this._state = 'camera_muted';
				ExternalCall.Simple(this.webcamError_Callback);
			}else{
				this._state = 'waiting';
				ExternalCall.Simple(this.webcamError_Callback);
			}
		}
		// Lance l'enregistrement
		public function StartRecord(arg1:String):void
		{
			this.Debug("Event: StartRecord()");
			this._state = "recording";
			
			ExternalCall.RecordStart(this.recordStart_Callback);
			
			_bitmaps = new Array();
			_startTime = getTimer();
			if(HAS_AUDIO){
				_micro.record();
			}
			captureFrame();
		}
		
		// Arrête l'enregistrement
		public function StopRecord():void
		{
			this.Debug("Event: StopRecord()");
			this._state = "encoding";
			clearTimeout(_timeoutId);
			var sec:int = int(_bitmaps.length / FLV_FRAMERATE);
			ExternalCall.RecordStop(this.recordStop_Callback,int(_bitmaps.length),sec);
			startEncoding();
			return;
		}
		
		// Enregistre chaque frame
		private function captureFrame():void
		{
			this.Debug("Event: Capture frame");
			// capture frame
			var b:BitmapData = new BitmapData(OUTPUT_WIDTH,OUTPUT_HEIGHT,false,0x0);
			b.draw(_video);
			_bitmaps.push(b);
			
			var sec:int = int(_bitmaps.length / FLV_FRAMERATE);
			this.Debug("0:"  +  ((sec < 10) ? ("0" + sec) : sec));
			
			// end condition:
			if (RECORD_MAX && (_bitmaps.length / FLV_FRAMERATE >= RECORD_MAX_TIME)) {
				ExternalCall.RecordStopForce(this.recordStopForce_Callback,int(_bitmaps.length),sec);
				StopRecord();
				return;
			}
			
			// schedule next captureFrame
			var elapsedMs:int = getTimer() - _startTime;
			var nextMs:int = (_bitmaps.length / FLV_FRAMERATE) * 1000;
			var deltaMs:int = nextMs - elapsedMs;
			if (deltaMs < 10) deltaMs = 10;
			
			ExternalCall.RecordProgress(this.recordProgress_Callback,_bitmaps.length,sec);
			
			_timeoutId = setTimeout(captureFrame, deltaMs);
		}
		
		public function CancelRecord():void
		{
			this.Debug("Event: CancelRecord()");
			ExternalCall.RecordCancel(this.recordCancel_Callback);
			this._state = "canceled";
			clearTimeout(_timeoutId);
			_baFlvEncoder.kill();
			return;
		}
		
		// Débute l'encodage après 100 ms
		private function startEncoding():void
		{
			this.Debug("Event: Startencoding()");
			ExternalCall.EncodeStart(this.encodeStart_Callback,_bitmaps.length);
			// Get just a little more Mic input!
			// (or enough time for last chunk of data to come in?)			
			setTimeout(startEncoding_2, 100);
		}
		
		// Lance l'encodage
		private function startEncoding_2():void
		{
			
			this.Debug("Event: Startencoding_2()");
			
			if(HAS_AUDIO) {
				_micro.stop();
				_audioData = _micro.byteArray;
				_baFlvEncoder.setAudioProperties(FlvEncoder.SAMPLERATE_44KHZ, true, false, true);
			}
			
			_baFlvEncoder = new ByteArrayFlvEncoder(FLV_FRAMERATE);
			//_baFlvEncoder.setVideoProperties(OUTPUT_WIDTH,OUTPUT_HEIGHT);
			//if(HAS_VIDEO){
				_baFlvEncoder.setVideoProperties(OUTPUT_WIDTH,OUTPUT_HEIGHT, VideoPayloadMakerAlchemy);
			//}
			_baFlvEncoder.start();
			
			_encodeFrameNum = -1; 
			
			this.addEventListener(Event.ENTER_FRAME, this.encodeFrame);
			return;
		}
		
		// Encode les frames
        internal function encodeFrame(e:*):void
        {
			this.Debug("Event: encodeFrame()");
			// Encode 3 frames per iteration
			for (var i:int = 0; i < 3; i++)
			{
				_encodeFrameNum++;
				
				if (_encodeFrameNum < _bitmaps.length) {
					encodeNextFrame();
				}
				else {
					// done
					this.removeEventListener(Event.ENTER_FRAME, this.encodeFrame);
					_baFlvEncoder.updateDurationMetadata();
					this.Size = _baFlvEncoder.byteArray.length;
					this._state = "encoded";
					this.Debug("Final size : " +this.Size);
					ExternalCall.EncodeStop(this.encodeStop_Callback,_bitmaps.length,this.Size);
					this.Debug("File saved in memory");
					//setState(States.SAVING);
					return;
				}
			}
			
			this.Debug("encoding frame " + (_encodeFrameNum+1) + " of " + _bitmaps.length);
			ExternalCall.EncodeProgress(this.encodeProgress_Callback,(_encodeFrameNum+1),_bitmaps.length,_baFlvEncoder.byteArray.length);
            return;
        }
		
		// Encode chaque frame
		private function encodeNextFrame():void
		{
			var baAudio:ByteArray;
			var bmdVideo:BitmapData;
			
			if (HAS_AUDIO)
			{
				baAudio = new ByteArray();
				var pos:int = _encodeFrameNum * _baFlvEncoder.audioFrameSize;
				
				if (pos < 0 || pos + _baFlvEncoder.audioFrameSize > _audioData.length) {
					this.Debug("out of bounds: "+ _encodeFrameNum+" pos"+pos+" "+ _baFlvEncoder.audioFrameSize+"versus _audioData"); 
					baAudio.length = _baFlvEncoder.audioFrameSize; // zero's
				}
				else {
					baAudio.writeBytes(_audioData, pos, _baFlvEncoder.audioFrameSize);
				}
			}
			//if(HAS_VIDEO)
				bmdVideo = _bitmaps[_encodeFrameNum];
			
			_baFlvEncoder.addFrame(bmdVideo, baAudio);
			
			// Video frame has been encoded, so we can discard it now
			_bitmaps[_encodeFrameNum].dispose();
		}
		
		// Envoi du fichier
		private function StartUpload():void {
			this._state = "sending";
			if(this.uploadURL == ''){
				// Save FLV file via FileReference
				var fileRef:FileReference = new FileReference();
				fileRef.save(_baFlvEncoder.byteArray, "test.flv");
				return;
			}
			else{ 
				if (this.current_file_item != null) {
					this.Debug("StartUpload(): Upload already in progress. Not starting another upload.");
					return;
				}
				// Get the next file to upload
				
				this.current_file_item = {};
				
				if (this.current_file_item != null) {
					// Trigger the uploadStart event which will call ReturnUploadStart to begin the actual upload
					this.Debug("Event: uploadStart ");
					
					this.file_status = FILE_STATUS_IN_PROGRESS;
					try {
						Debug(""+this.file_status);
						this.js_object={};
						this.js_object.filestatus = this.file_status;
						this.js_object.post = this.GetPostObject(true);
						
						var request:URLRequest = this.BuildRequest();
						request.url = this.uploadURL;
						request.contentType = 'multipart/form-data; boundary=' + UploadPostHelper1.getBoundary();
						request.method = URLRequestMethod.POST;
						request.data = UploadPostHelper1.getPostData( this.documentName, _baFlvEncoder.byteArray,request.data);
						request.requestHeaders.push(new URLRequestHeader('Cache-Control', 'no-cache'));
						
						loader = new URLLoader();
						loader.addEventListener(Event.OPEN, Open_Handler);
						loader.addEventListener(ProgressEvent.PROGRESS, this.FileProgress_Handler);
						loader.addEventListener(IOErrorEvent.IO_ERROR, this.IOError_Handler);
						loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.SecurityError_Handler);
						loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, this.HTTPError_Handler);
						loader.addEventListener(Event.COMPLETE, this.Complete_Handler);
						
						if (request.url.length == 0) {
							this.Debug("Event: uploadError : IO Error : Upload URL string is empty.");
							
							// Remove the event handlers
							this.removeFileReferenceEventListeners(loader);
							
							this.current_file_item.file_status = FILE_STATUS_QUEUED;
							
							js_object = this.current_file_item.ToJavaScriptObject();
							this.current_file_item = null;
							
							ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_MISSING_UPLOAD_URL, js_object, "Upload URL string is empty.");
						} else {
							this.Debug("File accepted by startUpload event and readied for upload.  Starting upload to " + request.url );
							this.current_file_item.file_status = FILE_STATUS_IN_PROGRESS;
							ExternalCall.UploadStart(this.uploadStart_Callback, this.js_object);
							loader.load(request);
						}
					} catch (ex:Error) {
						this.Debug("ReturnUploadStart: Exception occurred: " + message);
						
						this.current_file_item.file_status = FILE_STATUS_ERROR;
						
						var message:String = ex.errorID + "\n" + ex.name + "\n" + ex.message + "\n" + ex.getStackTrace();
						this.Debug("Event: uploadError(): Upload Failed. Exception occurred: " + message);
						ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_UPLOAD_FAILED, this.current_file_item.ToJavaScriptObject(), message);
						
						this.UploadComplete(true);
					}
				}
				// Otherwise we've would have looped through all the FileItems. This means the queue is empty)
				else {
					this.Debug("StartUpload(): No files found in the queue.");
				}
			}
		}
		
        public function getSize():int
        {
            return this.Size;
        }
		
		// Renvoi le statut de l'enregistreur
        public function getState():String
        {
            return this._state;
        }
		
	
		private function Open_Handler(event:Event):void {
			this.Debug("Event: uploadProgress (OPEN)");
			ExternalCall.UploadProgress(this.uploadProgress_Callback, this.current_file_item.ToJavaScriptObject(), 0, this.Size);
		}
		
		private function FileProgress_Handler(event:ProgressEvent):void {
			// On early than Mac OS X 10.3 bytesLoaded is always -1, convert this to zero. Do bytesTotal for good measure.
			//  http://livedocs.adobe.com/flex/3/langref/flash/net/FileReference.html#event:progress
			this.Debug("progressHandler loaded:" + event.bytesLoaded + " total: " + event.bytesTotal);
			var bytesLoaded:Number = event.bytesLoaded < 0 ? 0 : event.bytesLoaded;
			var bytesTotal:Number = event.bytesTotal < 0 ? 0 : event.bytesTotal;
			
			// Because Flash never fires a complete event if the server doesn't respond after 30 seconds or on Macs if there
			// is no content in the response we'll set a timer and assume that the upload is successful after the defined amount of
			// time.  If the timeout is zero then we won't use the timer.
			if (bytesLoaded === bytesTotal && bytesTotal > 0 && this.assumeSuccessTimeout > 0) {
				if (this.assumeSuccessTimer !== null) {
					this.assumeSuccessTimer.stop();
					this.assumeSuccessTimer = null;
				}
				
				this.assumeSuccessTimer = new Timer(this.assumeSuccessTimeout * 1000, 1);
				this.assumeSuccessTimer.addEventListener(TimerEvent.TIMER_COMPLETE, AssumeSuccessTimer_Handler);
				this.assumeSuccessTimer.start();
			}
			
			this.Debug("Event: uploadProgress: Bytes: " + bytesLoaded + ". Total: " + bytesTotal);
			ExternalCall.UploadProgress(this.uploadProgress_Callback, this.current_file_item.ToJavaScriptObject(), bytesLoaded, bytesTotal);
		}
		
		private function AssumeSuccessTimer_Handler(event:TimerEvent):void {
			this.Debug("Event: AssumeSuccess: " + this.assumeSuccessTimeout + " passed without server response");
			this.UploadSuccess("", false);
		}
		
		private function Complete_Handler(event:Event):void {
			this.Debug("Event: completehandler: Le server retourne ");
			/* Because we can't do COMPLETE or DATA events (we have to do both) we can't
			* just call uploadSuccess from the complete handler, we have to wait for
			* the Data event which may never come. However, testing shows it always comes
			* within a couple milliseconds if it is going to come so the solution is:
			* 
			* Set a timer in the COMPLETE event (which always fires) and if DATA is fired
			* it will stop the timer and call uploadComplete
			* 
			* If the timer expires then DATA won't be fired and we call uploadComplete
			* */
			
			// Set the timer
			Debug(event.currentTarget.data);
			this.UploadSuccess(event.currentTarget.data);
			return;
			if (serverDataTimer != null) {
				this.serverDataTimer.stop();
				this.serverDataTimer = null;
			}
			
			this.serverDataTimer = new Timer(100, 1);
			this.serverDataTimer.addEventListener(TimerEvent.TIMER, this.ServerDataTimer_Handler);
			this.serverDataTimer.start();
		}
		
		private function ServerDataTimer_Handler(event:TimerEvent):void {
			this.UploadSuccess("");
		}
		
		private function ServerData_Handler(event:DataEvent):void {
			this.Debug(event.data);
			Debug(event.currentTarget.data);
			this.UploadSuccess(event.data);
		}
		
		private function UploadSuccess(serverData:String, responseReceived:Boolean = true):void {
			if (this.serverDataTimer !== null) {
				this.serverDataTimer.stop();
				this.serverDataTimer = null;
			}
			if (this.assumeSuccessTimer !== null) {
				this.assumeSuccessTimer.stop();
				this.assumeSuccessTimer = null;
			}
			
			this.current_file_item.file_status = FILE_STATUS_SUCCESS;
			this._state = 'uploaded';
			this.Debug("Event: uploadSuccess:  Response Received: " + responseReceived.toString() + " Data: " + serverData);
			ExternalCall.UploadSuccess(this.uploadSuccess_Callback, this.js_object, serverData, responseReceived);
			this.UploadComplete();
		}
		
		private function HTTPError_Handler(event:HTTPStatusEvent):void {
			var isSuccessStatus:Boolean = false;
			for (var i:Number = 0; i < this.httpSuccess.length; i++) {
				if (this.httpSuccess[i] === event.status) {
					isSuccessStatus = true;
					break;
				}
			}
			if (isSuccessStatus) {
				this.Debug("Event: httpError: Translating status code " + event.status + " to uploadSuccess");
				var serverDataEvent:DataEvent = new DataEvent(DataEvent.UPLOAD_COMPLETE_DATA, event.bubbles, event.cancelable, "");
				this.ServerData_Handler(serverDataEvent);
			} else {
				this.current_file_item.file_status = FILE_STATUS_ERROR;
				this.Debug("Event: uploadError: HTTP ERROR :  HTTP Status: " + event.status + ".");
				ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_HTTP_ERROR, this.current_file_item.ToJavaScriptObject(), event.status.toString());
				this.UploadComplete(); 	// An IO Error is also called so we don't want to complete the upload yet.
			}
		}
		
		// Note: Flash Player does not support Uploads that require authentication. Attempting this will trigger an
		// IO Error or it will prompt for a username and password and may crash the browser (FireFox/Opera)
		private function IOError_Handler(event:IOErrorEvent):void {
			// Only trigger an IO Error event if we haven't already done an HTTP error
			if (this.file_status != FILE_STATUS_ERROR) {
				this.file_status = FILE_STATUS_ERROR;
				
				this.Debug("Event: uploadError : IO Error :  IO Error: " + event.text);
				ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_IO_ERROR, this.current_file_item.ToJavaScriptObject(), event.text);
			}
			
			this.UploadComplete();
		}
		
		private function SecurityError_Handler(event:SecurityErrorEvent):void {
			this.file_status = FILE_STATUS_ERROR;
			
			this.Debug("Event: uploadError : Security Error :  Error text: " + event.text);
			ExternalCall.UploadError(this.uploadError_Callback, this.ERROR_CODE_SECURITY_ERROR, this.current_file_item.ToJavaScriptObject(), event.text);
			
			this.UploadComplete();
		}
		
		// Completes the file upload by deleting it's reference, advancing the pointer.
		// Once this event fires a new upload can be started.
		private function UploadComplete():void {
			var jsFileObj:Object = this.current_file_item.ToJavaScriptObject();
			
			this.removeFileReferenceEventListeners(loader);
			
			this.Debug("Event: uploadComplete : Upload cycle complete.");
			ExternalCall.UploadComplete(this.uploadComplete_Callback, jsFileObj);
		}
		
		private function removeFileReferenceEventListeners(loader:URLLoader):void {
			if (loader != null) {
				loader.removeEventListener(Event.OPEN, this.Open_Handler);
				loader.removeEventListener(ProgressEvent.PROGRESS, this.FileProgress_Handler);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, this.IOError_Handler);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, this.SecurityError_Handler);
				loader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, this.HTTPError_Handler);
			}
		}
    }
}