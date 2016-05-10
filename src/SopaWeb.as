/*
Programmed by Kaoru ASHIHARA

Thanks to AWAY3D ( http://away3d.com/ )

Copyright AIST, 2016
*/

package
{
	// -------------------------------------------------------------------------------------------------------------------------------
	import flash.display.BitmapData;
	import flash.display.BlendMode;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.filters.DropShadowFilter;
	import flash.geom.Point;
	import flash.geom.Vector3D;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	import flash.ui.MouseCursorData;
	import flash.utils.getTimer;
	
	import SopaStreamer;
	
	import away3d.cameras.lenses.PerspectiveLens;
	import away3d.containers.View3D;
	import away3d.entities.Mesh;
	import away3d.materials.ColorMaterial;
	import away3d.materials.TextureMaterial;
	import away3d.primitives.PlaneGeometry;
	import away3d.textures.BitmapTexture;
	import away3d.textures.Texture2DBase;
	
	//	[SWF(width=960,height=480,framerate=30)]
	[SWF(width=stage.stageWidth,height=stage.stageHeight,framerate=30)]
	
	// -------------------------------------------------------------------------------------------------------------------------------		
	
	// -------------------------------------------------------------------------------------------------------------------------------
	public class SopaWeb extends Sprite
	{
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private var sopaStreamer:SopaStreamer;
		private var titleFormat:TextFormat = new TextFormat();
		private var myTitle:TextField = new TextField();
		private var nextTitle:TextField = new TextField();
		private var textFormat:TextFormat = new TextFormat();
		private var myTextField:TextField = new TextField();
		private var secondTextField:TextField = new TextField();
		//		private var sopaURL:String = "c:/myDir/mini/railway.sopa";
		private var sopaURL:String = "https://unit.aist.go.jp/hiri/hi-infodesign/as_ss0/sidewalk.sopa";
		private var ns_front:NetStream;
		private var ns_right:NetStream;
		private var ns_back:NetStream;
		private var ns_left:NetStream;
		private var ns_top:NetStream;
		private var ns_bottom:NetStream;
		
		private var nc_front:NetConnection;
		private var nc_right:NetConnection;
		private var nc_back:NetConnection;
		private var nc_left:NetConnection;
		private var nc_top:NetConnection;
		private var nc_bottom:NetConnection;
		
		private var view:View3D;
		
		private var video_front:Video;
		private var videoContainer_front:Sprite;
		private var video_right:Video;
		private var videoContainer_right:Sprite;
		private var video_back:Video;
		private var videoContainer_back:Sprite;
		private var video_left:Video;
		private var videoContainer_left:Sprite;
		private var video_top:Video;
		private var videoContainer_top:Sprite;
		private var video_bottom:Video;
		private var videoContainer_bottom:Sprite;
		
		private var bmpDataFront:BitmapData;
		private var bmpDataRight:BitmapData;
		private var bmpDataBack:BitmapData;
		private var bmpDataLeft:BitmapData;
		private var bmpDataTop:BitmapData;
		private var bmpDataBottom:BitmapData;
		
		private var bmpTextureFront:Texture2DBase;
		private var bmpTextureRight:Texture2DBase;
		private var bmpTextureBack:Texture2DBase;
		private var bmpTextureLeft:Texture2DBase;
		private var bmpTextureTop:Texture2DBase;
		private var bmpTextureBottom:Texture2DBase;
		
		private var planeTextureFront:TextureMaterial;
		private var planeTextureRight:TextureMaterial;
		private var planeTextureBack:TextureMaterial;
		private var planeTextureLeft:TextureMaterial;
		private var planeTextureTop:TextureMaterial;
		private var planeTextureBottom:TextureMaterial;
		
		private var planeGeom:PlaneGeometry;
		private var planeFront:Mesh;
		private var planeRight:Mesh;
		private var planeLeft:Mesh;
		private var planeBack:Mesh;
		private var planeTop:Mesh;
		private var planeBottom:Mesh;
		
		private var videoW:Number = 512;
		private var videoH:Number = 512;
		private var nThresholdX:Number;
		private var nThresholdY:Number;
		private var iCountVideo:int;
		private var timeIni:int;
		private var timeElapsed:int;
		private var horizontalAngle:Number = 0.0;
		private var verticalAngle:Number = 0.0;
		private const SENS:Number = 1;
		private const PLANE_NUM:int = 6;
		
		private var isOut:Boolean;
		private var isPlaying:Boolean;
		
		[Embed(source = "x_cursor.png"] private static const xCursor:Class;
		[Embed(source = "up_cursor.png"] private static const upCursor:Class;
		[Embed(source = "down_cursor.png"] private static const downCursor:Class;
		[Embed(source = "left_cursor.png"] private static const leftCursor:Class;
		[Embed(source = "right_cursor.png"] private static const rightCursor:Class;
		
		// ---------------------------------------------------------------------------------------------------------------------------				
		
		// ---------------------------------------------------------------------------------------------------------------------------
		public function SopaWeb()
		{
			// Setup class specific tracer
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			
			nThresholdX = stage.stageWidth / 4;
			nThresholdY = stage.stageHeight / 4;
			
			iCountVideo = 0;
			isOut = false;
			isPlaying = false;
			
			this.addEventListener(Event.ADDED_TO_STAGE,init);
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		
		// ---------------------------------------------------------------------------------------------------------------------------
		public function init(e:Event=null):void
		{	
			var iMargin:int = 8;
			timeElapsed = 8192;
			
			// Clean up stage added listener
			this.removeEventListener(Event.ADDED_TO_STAGE,init);
			
			textFormat.color = 0xffff99;
			textFormat.size = 36;
			textFormat.align = TextFormatAlign.CENTER;
			
			myTextField.autoSize = TextFieldAutoSize.LEFT;
			myTextField.y = iMargin;
			myTextField.x = stage.stageWidth / 10 + iMargin;
			myTextField.defaultTextFormat = textFormat;
			myTextField.text = "Loading data";
			myTextField.filters = [new DropShadowFilter()];
			
			secondTextField.autoSize = TextFieldAutoSize.LEFT;
			secondTextField.y = iMargin * 2 + myTextField.height;
			secondTextField.x = stage.stageWidth / 10 + iMargin;
			secondTextField.defaultTextFormat = textFormat;
			secondTextField.text = "Please wait for a while";
			secondTextField.filters = [new DropShadowFilter()];
			
			addChild(myTextField);
			addChild(secondTextField);
			
			horizontalAngle = verticalAngle = 0;
			sopaStreamer = new SopaStreamer();
			sopaStreamer.sopaURL = sopaURL;
			sopaStreamer.nSamplesDone = 0;
			sopaStreamer.sopaPrepare();
			
			// Setup Away3D 4
			setupAway3D();
			
			// Setup video material (which is next to the same as making a video player via netstream)
			setupVideoMaterial();
			
			// Build our Away3D 4 scene
			buildScene();
			
			var isReadyToPlay:Boolean = sopaStreamer.isPrepared;
			var isSopaFailed:Boolean = sopaStreamer.isFailed;
			while(!isReadyToPlay && !isSopaFailed && !sopaStreamer.isReady){
				var iLap:int = getTimer();
				isReadyToPlay = sopaStreamer.isPrepared;
				isSopaFailed = sopaStreamer.isFailed;
			}	
			if(sopaStreamer.isFailed){
				secondTextField.text = "Failed to load data!";
			}
			else{
				runVideo();
				
				// Listen up!
				initEventListeners();
				createNativeCursor();
			}
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function createNativeCursor() : void {
			var xCursorData:MouseCursorData = new MouseCursorData();
			var xBitmapDatas:Vector.<BitmapData> = new <BitmapData>[new xCursor().bitmapData];
			xCursorData.data = xBitmapDatas;
			Mouse.registerCursor("xCursor",xCursorData);
			
			var upCursorData:MouseCursorData = new MouseCursorData();
			var upBitmapDatas:Vector.<BitmapData> = new <BitmapData>[new upCursor().bitmapData];
			upCursorData.data = upBitmapDatas;
			upCursorData.hotSpot = new Point(0,0);
			Mouse.registerCursor("upCursor",upCursorData);	
			
			var downCursorData:MouseCursorData = new MouseCursorData();
			var downBitmapDatas:Vector.<BitmapData> = new <BitmapData>[new downCursor().bitmapData];
			downCursorData.data = downBitmapDatas;
			downCursorData.hotSpot = new Point(0,31);
			Mouse.registerCursor("downCursor",downCursorData);	
			
			var leftCursorData:MouseCursorData = new MouseCursorData();
			var leftBitmapDatas:Vector.<BitmapData> = new <BitmapData>[new leftCursor().bitmapData];
			leftCursorData.data = leftBitmapDatas;
			Mouse.registerCursor("leftCursor",leftCursorData);	
			
			var rightCursorData:MouseCursorData = new MouseCursorData();
			var rightBitmapDatas:Vector.<BitmapData> = new <BitmapData>[new rightCursor().bitmapData];
			rightCursorData.data = rightBitmapDatas;
			rightCursorData.hotSpot = new Point(31,0);
			Mouse.registerCursor("rightCursor",rightCursorData);	
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function onPlay(event:MouseEvent):void{
			if(isPlaying){
				sopaStreamer.nSamplesDone = sopaStreamer.iSamplesPerChannel;
				
				ns_front.pause();
				ns_right.pause();
				ns_back.pause();
				ns_left.pause();
				ns_bottom.pause();
				ns_top.pause();
				
				isPlaying = false;
				iCountVideo = 0;
				timeElapsed = 8192;
				
				myTextField.text = "Reproduction cancelled";
				secondTextField.text ="Copyright (c) 2016 AIST";
			}
			else{
				if(secondTextField.text == "Click to start"){
					ns_front.resume();
					ns_right.resume();
					ns_back.resume();
					ns_left.resume();
					ns_bottom.resume();
					ns_top.resume();
					if(sopaStreamer.openSopaFile()){
						isPlaying = true;
						myTextField.text = sopaURL;
						
						secondTextField.text = "Please use stereo headphones.";
						timeElapsed = 0;
						timeIni = getTimer();	
					}
					else{
						isPlaying = false;	
						secondTextField.text = "Failed to reproduce the SOPA file";
					}
				}
				else
					runVideo();
			}
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function runVideo():void{
			if(!isPlaying){
				var tmpStr:String = sopaURL.substr(0,sopaURL.lastIndexOf("."));
				var urlStrFront:String = tmpStr +"0.flv";
				var urlStrRight:String = tmpStr +"1.flv";
				var urlStrBack:String = tmpStr +"2.flv";
				var urlStrLeft:String = tmpStr +"3.flv";
				var urlStrBottom:String = tmpStr +"4.flv";
				var urlStrTop:String = tmpStr +"5.flv";
				
				ns_front.play(urlStrFront);
				ns_front.pause();
				ns_right.play(urlStrRight);
				ns_right.pause();
				ns_back.play(urlStrBack);
				ns_back.pause();
				ns_left.play(urlStrLeft);
				ns_left.pause();
				ns_bottom.play(urlStrBottom);
				ns_bottom.pause();
				ns_top.play(urlStrTop);
				ns_top.pause();
				
			}
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		private function setupAway3D():void
		{
			// Init Away3D
			view = new View3D;
			view.backgroundColor = 0x000000;
			view.y = 0;
			view.x = 0;
			view.width = stage.stageWidth;
			view.height = stage.stageHeight;
			addChild(view);
			
			//setup the camera
			view.camera.z = -256;
			view.camera.y = 0;
			view.camera.x = 0;
			view.camera.lookAt(new Vector3D());
			view.camera.lens = new PerspectiveLens(90);
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		private function setupVideoMaterial():void
		{
			/* GUIDE:
			On each enter frame we are going to update bitmap which is used for the material/texture on the mesh (planeMesh)
			1. Build a video player
			2. Grab BitmapData of the video player on enterframe and update the TextureMaterial
			*/
			
			// Setup video
			video_front = new Video(videoW,videoH);
			video_right = new Video(videoW,videoH);
			video_back = new Video(videoW,videoH);
			video_left = new Video(videoW,videoH);
			video_bottom = new Video(videoW,videoH);
			video_top = new Video(videoW,videoH);
			
			// For front plane
			nc_front = new NetConnection();
			nc_front.addEventListener(NetStatusEvent.NET_STATUS, frontHandler);
			nc_front.connect(null);
			
			videoContainer_front = new Sprite();
			videoContainer_front.addChild(video_front);
			
			// For right plane
			nc_right = new NetConnection();
			nc_right.addEventListener(NetStatusEvent.NET_STATUS, rightHandler);
			nc_right.connect(null);
			
			videoContainer_right = new Sprite();
			videoContainer_right.addChild(video_right);
			
			// For back plane
			nc_back = new NetConnection();
			nc_back.addEventListener(NetStatusEvent.NET_STATUS, backHandler);
			nc_back.connect(null);
			
			videoContainer_back = new Sprite();
			videoContainer_back.addChild(video_back);
			
			// For left plane
			nc_left = new NetConnection();
			nc_left.addEventListener(NetStatusEvent.NET_STATUS, leftHandler);
			nc_left.connect(null);
			
			videoContainer_left = new Sprite();
			videoContainer_left.addChild(video_left);
			
			// For bottom plane
			nc_bottom = new NetConnection();
			nc_bottom.addEventListener(NetStatusEvent.NET_STATUS, bottomHandler);
			nc_bottom.connect(null);
			
			videoContainer_bottom = new Sprite();
			videoContainer_bottom.addChild(video_bottom);	
			
			// For top plane
			nc_top = new NetConnection();
			nc_top.addEventListener(NetStatusEvent.NET_STATUS, topHandler);
			nc_top.connect(null);
			
			videoContainer_top = new Sprite();
			videoContainer_top.addChild(video_top);	
			
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function frontHandler(e:NetStatusEvent):void{
			if(e.info.code == "NetConnection.Connect.Success"){
				ns_front = new NetStream(nc_front);
				var client:Object = new Object( );
				client.onMetaData = function(o:Object):void {};
				client.onCuePoint = function(o:Object):void {};
				ns_front.client = client;
				ns_front.addEventListener(NetStatusEvent.NET_STATUS, statusChanged);
				
				video_front.attachNetStream(ns_front);
			}
			else{
				secondTextField.text = "NetConnection failed!";
				iCountVideo = 0;
			}
			
			nc_front.removeEventListener(NetStatusEvent.NET_STATUS, frontHandler);
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function rightHandler(e:NetStatusEvent):void{
			if(e.info.code == "NetConnection.Connect.Success"){
				ns_right = new NetStream(nc_right);
				
				var client:Object = new Object( );
				client.onMetaData = function(o:Object):void {};
				client.onCuePoint = function(o:Object):void {};
				ns_right.client = client;
				ns_right.addEventListener(NetStatusEvent.NET_STATUS, statusChanged);					
				
				video_right.attachNetStream(ns_right);
			}
			else{
				secondTextField.text = "NetConnection failed!";
				iCountVideo = 0;
			}
			
			nc_right.removeEventListener(NetStatusEvent.NET_STATUS, rightHandler);
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function backHandler(e:NetStatusEvent):void{
			if(e.info.code == "NetConnection.Connect.Success"){
				ns_back = new NetStream(nc_back);
				
				var client:Object = new Object( );
				client.onMetaData = function(o:Object):void {};
				client.onCuePoint = function(o:Object):void {};
				ns_back.client = client;
				ns_back.addEventListener(NetStatusEvent.NET_STATUS, statusChanged);					
				
				video_back.attachNetStream(ns_back);
			}
			else{
				secondTextField.text = "NetConnection failed!";
				iCountVideo = 0;
			}
			
			nc_back.removeEventListener(NetStatusEvent.NET_STATUS, backHandler);
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function leftHandler(e:NetStatusEvent):void{
			if(e.info.code == "NetConnection.Connect.Success"){
				ns_left = new NetStream(nc_left);
				
				var client:Object = new Object( );
				client.onMetaData = function(o:Object):void {};
				client.onCuePoint = function(o:Object):void {};
				ns_left.client = client;
				ns_left.addEventListener(NetStatusEvent.NET_STATUS, statusChanged);					
				
				video_left.attachNetStream(ns_left);
			}
			else{
				secondTextField.text = "NetConnection failed!";
				iCountVideo = 0;
			}
			
			nc_left.removeEventListener(NetStatusEvent.NET_STATUS, leftHandler);
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function bottomHandler(e:NetStatusEvent):void{
			if(e.info.code == "NetConnection.Connect.Success"){
				ns_bottom = new NetStream(nc_bottom);
				
				var client:Object = new Object( );
				client.onMetaData = function(o:Object):void {};
				client.onCuePoint = function(o:Object):void {};
				ns_bottom.client = client;
				ns_bottom.addEventListener(NetStatusEvent.NET_STATUS, statusChanged);					
				
				video_bottom.attachNetStream(ns_bottom);
			}
			else{
				secondTextField.text = "NetConnection failed!";
				iCountVideo = 0;
			}
			
			nc_bottom.removeEventListener(NetStatusEvent.NET_STATUS, bottomHandler);
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function topHandler(e:NetStatusEvent):void{
			if(e.info.code == "NetConnection.Connect.Success"){
				ns_top = new NetStream(nc_top);
				
				var client:Object = new Object( );
				client.onMetaData = function(o:Object):void {};
				client.onCuePoint = function(o:Object):void {};
				ns_top.client = client;
				ns_top.addEventListener(NetStatusEvent.NET_STATUS, statusChanged);					
				
				video_top.attachNetStream(ns_top);				
			}
			else{
				secondTextField.text = "NetConnection failed!";
				iCountVideo = 0;
			}
			nc_top.removeEventListener(NetStatusEvent.NET_STATUS, topHandler);
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function statusChanged(e:NetStatusEvent):void{
			if(e.info.code == "NetStream.Play.Start"){
				iCountVideo ++;
				if(iCountVideo == PLANE_NUM){
					if(secondTextField.text == "Please wait for a while"){
						myTextField.text = "Please use stereo headphones";
						secondTextField.text = "Click to start";
						myTitle.text = "Panoramic sound recorded by";
						myTitle.alpha = 1;
						nextTitle.text = "a Miniature Head Simulator";
						nextTitle.alpha = 1;
					}
					else{
						ns_front.resume();
						ns_right.resume();
						ns_back.resume();
						ns_left.resume();
						ns_bottom.resume();
						ns_top.resume();
						if(sopaStreamer.openSopaFile()){
							isPlaying = true;
							myTextField.text = sopaURL;
							//							secondTextField.text = "is on the air. Click to stop reproduction.";
							secondTextField.text = "Please use stereo headphones.";
							myTitle.text = "Panoramic sound recorded by";
							myTitle.alpha = 1;
							nextTitle.text = "a Miniature Head Simulator";
							nextTitle.alpha = 1;
							timeIni = getTimer();
							timeElapsed = 0;
						}
						else{
							isPlaying = false;	
							secondTextField.text = "Failed to reproduce the SOPA file";
						}
					}
				}
			}
			else if(e.info.code == "NetStream.Play.Stop"){
				iCountVideo --;
				if(iCountVideo == 0){
					isPlaying = false;
					myTextField.text = "Reproduction completed";
					secondTextField.text ="Copyright (c) 2016 AIST";
					myTitle.text = "Thank you";
					myTitle.alpha = 1;
					nextTitle.text = "";
					nextTitle.alpha = 1;
				}
			}
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		private function buildScene():void
		{
			// Var ini
			bmpDataFront = new BitmapData(videoW,videoH);
			bmpDataRight = new BitmapData(videoW,videoH);
			bmpDataBack = new BitmapData(videoW,videoH);
			bmpDataLeft = new BitmapData(videoW,videoH);
			bmpDataBottom = new BitmapData(videoW,videoH);
			bmpDataTop = new BitmapData(videoW,videoH);
			
			planeGeom = new PlaneGeometry(videoW,videoH);
			planeFront = new Mesh(planeGeom,new ColorMaterial(Math.random()*0xFFFFFF));
			planeFront.rotationX = -90;
			view.scene.addChild(planeFront);
			
			planeRight = new Mesh(planeGeom,new ColorMaterial(Math.random()*0xFFFFFF));
			planeRight.rotationX = -90;
			planeRight.rotationY = 90;
			planeRight.x = videoW / 2;
			planeRight.z = -videoW / 2;
			view.scene.addChild(planeRight);
			
			planeBack = new Mesh(planeGeom,new ColorMaterial(Math.random()*0xFFFFFF));
			planeBack.rotationX = -90;
			planeBack.rotationY = 180;
			planeBack.z = -videoW;
			view.scene.addChild(planeBack);
			
			planeLeft = new Mesh(planeGeom,new ColorMaterial(Math.random()*0xFFFFFF));
			planeLeft.rotationX = -90;
			planeLeft.rotationY = 270;
			planeLeft.x = -videoW / 2;
			planeLeft.z = -videoW / 2;
			view.scene.addChild(planeLeft);
			
			planeBottom = new Mesh(planeGeom,new ColorMaterial(Math.random()*0xFFFFFF));
			planeBottom.rotationX = 0;
			planeBottom.y = -videoH / 2;
			planeBottom.z = -videoW / 2;
			view.scene.addChild(planeBottom);	
			
			planeTop = new Mesh(planeGeom,new ColorMaterial(Math.random()*0xFFFFFF));
			planeTop.rotationX = 180;
			planeTop.y = videoH / 2;
			planeTop.z = -videoW / 2;
			view.scene.addChild(planeTop);	
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		private function mouseLeft(event:MouseEvent):void{
			isOut = true;
			Mouse.cursor = MouseCursor.AUTO;
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		private function mouseIn(event:MouseEvent):void{
			isOut = false;
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		private function updatePlaneTextureUsingVideo():void
		{
			// Draw!
			bmpDataFront.draw(videoContainer_front);
			if(!bmpTextureFront)
				bmpTextureFront = new BitmapTexture(bmpDataFront);
			else{
				bmpTextureFront.dispose();
				bmpTextureFront = new BitmapTexture(bmpDataFront);
			}
			
			bmpDataRight.draw(videoContainer_right);
			if(!bmpTextureRight)
				bmpTextureRight = new BitmapTexture(bmpDataRight);
			else{
				bmpTextureRight.dispose();
				bmpTextureRight = new BitmapTexture(bmpDataRight);
			}
			
			bmpDataBack.draw(videoContainer_back);
			if(!bmpTextureBack)
				bmpTextureBack = new BitmapTexture(bmpDataBack);
			else{
				bmpTextureBack.dispose();
				bmpTextureBack = new BitmapTexture(bmpDataBack);
			}
			
			bmpDataLeft.draw(videoContainer_left);
			if(!bmpTextureLeft)
				bmpTextureLeft = new BitmapTexture(bmpDataLeft);
			else{
				bmpTextureLeft.dispose();
				bmpTextureLeft = new BitmapTexture(bmpDataLeft);
			}
			
			bmpDataBottom.draw(videoContainer_bottom);
			if(!bmpTextureBottom)
				bmpTextureBottom = new BitmapTexture(bmpDataBottom);
			else{
				bmpTextureBottom.dispose();
				bmpTextureBottom = new BitmapTexture(bmpDataBottom);
			}	
			
			bmpDataTop.draw(videoContainer_top);
			if(!bmpTextureTop)
				bmpTextureTop = new BitmapTexture(bmpDataTop);
			else{
				bmpTextureTop.dispose();
				bmpTextureTop = new BitmapTexture(bmpDataTop);
			}	
			
			// Set texture
			if(!planeTextureFront)
				planeTextureFront = new TextureMaterial(bmpTextureFront,false,false,true);
			else
				planeTextureFront.texture = bmpTextureFront;
			planeFront.material = planeTextureFront;
			
			if(!planeTextureRight)
				planeTextureRight = new TextureMaterial(bmpTextureRight,false,false,true);
			else
				planeTextureRight.texture = bmpTextureRight;
			planeRight.material = planeTextureRight;
			
			if(!planeTextureBack)
				planeTextureBack = new TextureMaterial(bmpTextureBack,false,false,true);
			else
				planeTextureBack.texture = bmpTextureBack;
			planeBack.material = planeTextureBack;
			
			if(!planeTextureLeft)
				planeTextureLeft = new TextureMaterial(bmpTextureLeft,false,false,true);
			else
				planeTextureLeft.texture = bmpTextureLeft;
			planeLeft.material = planeTextureLeft;
			
			if(!planeTextureBottom)
				planeTextureBottom = new TextureMaterial(bmpTextureBottom,false,false,true);
			else
				planeTextureBottom.texture = bmpTextureBottom;
			planeBottom.material = planeTextureBottom;	
			
			if(!planeTextureTop)
				planeTextureTop = new TextureMaterial(bmpTextureTop,false,false,true);
			else
				planeTextureTop.texture = bmpTextureTop;
			planeTop.material = planeTextureTop;	
		}
		
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		private function initEventListeners():void
		{			
			// Enter frame handler
			stage.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
			stage.addEventListener(MouseEvent.MOUSE_OUT,mouseLeft);
			stage.addEventListener(MouseEvent.MOUSE_OVER,mouseIn);
			stage.addEventListener(MouseEvent.CLICK,onPlay);			
			
			titleFormat.color = 0xffff33;
			titleFormat.size = 48;
			titleFormat.align = TextFormatAlign.LEFT;
			titleFormat.font = "Berlin Sans FB";
			
			myTitle.autoSize = TextFieldAutoSize.CENTER;
			myTitle.backgroundColor = 0xff000000;
			myTitle.defaultTextFormat = titleFormat;
			myTitle.blendMode = BlendMode.LAYER;
			myTitle.filters = [new DropShadowFilter()];
			myTitle.text = "Preparing";
			myTitle.x = stage.stageWidth / 2;
			myTitle.y = (stage.stageHeight + myTitle.height) / 2;
			myTitle.alpha = 1;
			
			nextTitle.autoSize = TextFieldAutoSize.CENTER;
			nextTitle.backgroundColor = 0xff000000;
			nextTitle.defaultTextFormat = titleFormat;
			nextTitle.blendMode = BlendMode.LAYER;
			nextTitle.filters = [new DropShadowFilter()];
			nextTitle.text = "Wait for a while";
			nextTitle.x = stage.stageWidth / 2;
			nextTitle.y = stage.stageHeight / 2 + myTitle.height * 2;
			nextTitle.alpha = 1;
			
			addChild(myTitle);
			addChild(nextTitle);
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------------------------------------------------
		private function enterFrameHandler(e:Event=null):void
		{
			var nPan:Number;
			var nTilt:Number;
			var nPosX:Number = view.mouseX - view.width / 2;
			var nPosY:Number = view.mouseY - view.height / 2;
			
			updatePlaneTextureUsingVideo();
			
			if(timeElapsed < 8192){
				myTitle.alpha = nextTitle.alpha = (8192 - timeElapsed) / 8192;
				timeElapsed = getTimer() - timeIni;
				if(timeElapsed >= 8192){
					myTitle.text = nextTitle.text = "";
					secondTextField.text = "Move the mouse pointer to control panning.";
				}
			}
			
			if(!isOut){
				if(Math.abs(nPosX) > nThresholdX){
					if(nPosX > 0){
						nPan = (nPosX - nThresholdX) * SENS / nThresholdX;
						Mouse.cursor = "rightCursor";
					}
					else{
						nPan = (nThresholdX + nPosX) * SENS / nThresholdX;
						Mouse.cursor = "leftCursor";
					}
				}
				else
					nPan = 0;
				
				if(Math.abs(nPosY) > nThresholdY){
					if(nPosY > 0){
						nTilt = (nPosY - nThresholdY) * SENS / nThresholdY;
						Mouse.cursor = "downCursor";
					}
					else{
						nTilt = (nThresholdY + nPosY) * SENS / nThresholdY;						
						Mouse.cursor = "upCursor";
					}
				}
				else
					nTilt = 0;
				
				if(nPan == 0 && nTilt == 0)
					Mouse.cursor = MouseCursor.HAND;
				
				horizontalAngle -= nPan * Math.PI / 180.0;
				verticalAngle += nTilt * Math.PI / 180;
				if(verticalAngle > Math.PI / 4){
					verticalAngle = Math.PI / 4;
					nTilt = 0;
					Mouse.cursor = "xCursor";
				}
				else if(verticalAngle < -Math.PI / 4){
					verticalAngle = -Math.PI / 4;
					nTilt = 0;
					Mouse.cursor = "xCursor";
				}
				while(horizontalAngle > Math.PI)
					horizontalAngle -= 2 * Math.PI;
				while(horizontalAngle <= -Math.PI)
					horizontalAngle += Math.PI * 2;
				
				var nDir:Number = horizontalAngle * 36 / Math.PI;
				nDir += 36;
				var iHori:int = nDir;
				nDir = verticalAngle * 36 / Math.PI;
				nDir += 18;
				var iVert:int = nDir;
				sopaStreamer.horizontalAngle = iHori;
				sopaStreamer.verticalAngle = iVert;	
				
				view.camera.rotationY += nPan;
				view.camera.rotationX += nTilt;
			}	
			
			view.render();
		}
		// ---------------------------------------------------------------------------------------------------------------------------
		
		
	}
	// -------------------------------------------------------------------------------------------------------------------------------
}