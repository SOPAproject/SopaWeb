package
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SampleDataEvent;
	import flash.events.SecurityErrorEvent;
	import flash.geom.Vector3D;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundMixer;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	public class SopaStreamer
	{
		private var sopaLoader:URLStream;
		private var _sopaURL:String;
		private var hrtfLoad:URLLoader = new URLLoader();
		private var phaseLoad:URLLoader = new URLLoader();
		private var hrtfVect:Vector.<int> = new Vector.<int>();
		private var phaseVect:Vector.<int> = new Vector.<int>();
		private var dirArray:Vector.<Vector.<Vector.<int>>> = new Vector.<Vector.<Vector.<int>>>(256);
		private var tmpArray:ByteArray;
		private var sopaArray:ByteArray;
		
		private var coordVect:Vector.<Vector3D> = new Vector.<Vector3D>();
		
		private var _isRunning:Boolean;
		private var _isFailed:Boolean;
		private var _isReady:Boolean;
		private var _horizontalAngle:int;
		private var _verticalAngle:int;
		private var iSize:int;
		private var _nSamplesDone:Number;
		private var _iSamplesPerChannel:int;
		private var soundStream:Vector.<int>;
		private var loopStream:Vector.<Number>;
		private var anglStream:Vector.<int>;
		private var realVect:Vector.<Number>;
		private var imageVect:Vector.<Number>;
		private var nHan:Vector.<Number>;
		private var iOverlap:int;
		
		private const iBlock:int = 2048;
		private const CHANNELS:int = 2;
		private var iVersion:Vector.<int>;
		private var iByte:int;
		private var iSampleRate:int;
		private var iChunkSize:int;
		private var iRatio:int;
		private var iRateConv:int;
		private var iSopaVersion:int;
		private var nBytesRead:Number;
		private var nBytesLoaded:Number;
		private var nOffset:Number;
		private var iProc:int;
		private var iRem:int;
		private var iHalf:int;
		private var mySound:Sound;
		private var iTest:int;
		private const dWpi:Number = Math.PI * 2;
		private var _isFinished:Boolean;
		private var _isPrepared:Boolean;
		
		public function SopaStreamer()
		{
			_isRunning = false;
			_isFailed = false;
			_isReady = false;
			_isPrepared = false;			
		}
		
		public function set horizontalAngle(ha:int):void{
			_horizontalAngle = ha;
		}
		
		public function set verticalAngle(va:int):void{
			_verticalAngle = va;
		}
		
		public function set sopaURL(strURL:String):void{
			_sopaURL = strURL;
		}
		
		public function set nSamplesDone(nS:Number):void{
			_nSamplesDone = nS;
		}
		
		public function get nSamplesDone():Number{
			return _nSamplesDone;
		}
		
		public function get isFailed():Boolean{
			return _isFailed;
		}
		
		public function get isRunning():Boolean{
			return _isRunning;
		}
		
		public function get isReady():Boolean{
			return _isReady;
		}
		
		public function get isFinished():Boolean{
			return _isFinished;
		}
		
		public function get isPrepared():Boolean{
			return _isPrepared;
		}
		
		public function get iSamplesPerChannel():int{
			return _iSamplesPerChannel;
		}
		
		/************************************************************************************************
		 * 									Stream Of Panoramic Audio									*	
		 ************************************************************************************************/	
		//	Database preparation		
		/*	************************** Load database **************************	*/
		public function sopaPrepare():void{
			var nPan:Number,nTilt:Number;
			var tmpStr:String = _sopaURL.substr(0,_sopaURL.lastIndexOf("/"));
			var binStr:String = tmpStr + "/hrtf3d512.bin";
			
			if(hrtfVect.length == 0){
				hrtfLoad.dataFormat = URLLoaderDataFormat.BINARY;
				hrtfLoad.addEventListener(Event.COMPLETE,hrtfComplete);
				hrtfLoad.addEventListener(IOErrorEvent.IO_ERROR,onIOerror);
				hrtfLoad.load(new URLRequest(binStr));
			}
			
			binStr = tmpStr + "/phase3d512.bin";
			if(phaseVect.length == 0){
				phaseLoad.dataFormat = URLLoaderDataFormat.BINARY;
				phaseLoad.addEventListener(Event.COMPLETE,phaseComplete);
				phaseLoad.addEventListener(IOErrorEvent.IO_ERROR,onIOerror);
				phaseLoad.load(new URLRequest(binStr));
			}
			
			for(var iSectNum:int = 0;iSectNum < 254;iSectNum ++){
				coordVect[iSectNum] = initCoord(iSectNum);
			}
			
			for(iSectNum = 0;iSectNum < 256;iSectNum ++){
				dirArray[iSectNum] = new Vector.<Vector.<int>>(72);
				for(var iPan:int = 0;iPan < 72;iPan ++){
					dirArray[iSectNum][iPan] = new Vector.<int>(36);
					if(iPan >= 36)
						nPan = -Math.PI * (72 - Number(iPan)) / 36;
					else
						nPan = Math.PI * Number(iPan) / 36;
					for(var iTilt:int = -18;iTilt < 18;iTilt ++){
						nTilt = Math.PI * Number(iTilt) / 36;
						var iVal:int = modifySector(iSectNum,nPan,nTilt);
						dirArray[iSectNum][iPan][iTilt + 18] = iVal;
					}
				}
			}	
			_isPrepared = true;
		}
		public function hrtfComplete(event:Event):void{
			var urlLoader:URLLoader = event.currentTarget as URLLoader;
			var byteStream:ByteArray = urlLoader.data as ByteArray;
			var iVal:int;
			
			byteStream.endian = Endian.LITTLE_ENDIAN;
			while(byteStream.bytesAvailable){
				iVal = byteStream.readShort();
				hrtfVect.push(iVal);
			}	
			if(hrtfVect.length != 130048)
				_isFailed = true;
			else if(phaseVect.length == 130048){
				_isReady = true;
			}
		}
		public function phaseComplete(event:Event):void{
			var urlLoader:URLLoader = event.currentTarget as URLLoader;
			var byteStream:ByteArray = urlLoader.data as ByteArray;
			var iVal:int;
			
			byteStream.endian = Endian.LITTLE_ENDIAN;
			while(byteStream.bytesAvailable){
				iVal = byteStream.readShort();
				phaseVect.push(iVal);
			}	
			if(phaseVect.length != 130048)
				_isFailed = true;
			else if(hrtfVect.length == 130048){
				_isReady = true;
			}
		}
		
		private function onIOerror(event:IOErrorEvent):void{
			_isFailed = true;
		}
		
		//	Open SOPA file		
		/*	************************** Check file header **************************	*/
		public function openSopaFile():Boolean{
			var sopaURL:URLRequest = new URLRequest(_sopaURL);
			
			if(_nSamplesDone > 0){
				_iSamplesPerChannel = _nSamplesDone;
				return false;
			}
			
			_isFinished = false;
			nBytesLoaded = nOffset = 0;
			iSize = iTest = 0;
			sopaLoader = new URLStream();
			sopaArray = new ByteArray();
			tmpArray = new ByteArray();
			
			configureListeners(sopaLoader);
			try{
				sopaLoader.load(sopaURL);
			}catch (error:Error) {
				return false;
			}
			return true;
		}
		
		private function configureListeners(dispatcher:EventDispatcher):void {
			dispatcher.addEventListener(Event.COMPLETE, onSopaLoaded);
			dispatcher.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
			dispatcher.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			dispatcher.addEventListener(Event.OPEN, openHandler);
			dispatcher.addEventListener(ProgressEvent.PROGRESS, onSopaProgress);
			dispatcher.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
		}
		
		private function openHandler(event:Event):void {
			trace("openHandler: " + event);
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void {
			_nSamplesDone = _iSamplesPerChannel;
			_isFailed = true;
		}
		
		private function httpStatusHandler(event:HTTPStatusEvent):void {
			trace("httpStatusHandler: " + event);
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void {
			_nSamplesDone = _iSamplesPerChannel;
			_isFailed = true;
		}
		
		public function onSopaProgress(event:ProgressEvent):void{
			var iPreLoad:int = iBlock * CHANNELS * 2 * 4;
			
			sopaArray.endian = Endian.LITTLE_ENDIAN;
			tmpArray.position = 0;
			for(var iCnt:int = 0;iCnt < nOffset;iCnt ++){
				sopaArray.writeByte(tmpArray.readByte());
			}
			
			if(iSize == 0){
				soundStream = new Vector.<int>();
				anglStream = new Vector.<int>();
				sopaLoader.readBytes(sopaArray,sopaArray.length);
			}
			else
				sopaLoader.readBytes(sopaArray,nOffset);

			if(sopaArray.length > 44 + iPreLoad && iSize == 0){
				if(!checkHeader(sopaArray)){
					_isFailed = true;
					return;
				}
				iOverlap = 2;
				
				if(iSampleRate != 22050 && iSampleRate != 44100){
					_isFailed = true;
					return;
				}
				
				iRatio = 44100 / iSampleRate;
				iRateConv = 44100 / iSampleRate;
				
				iSopaVersion = iVersion[3];
				
				_iSamplesPerChannel = iChunkSize / iByte / CHANNELS;
				
				var nCnt:Number = 0;
				var iEven:int,iOdd:int;
				var iVal:int;
				
				sopaArray.position = 44;
				nBytesRead = 44;
				while(sopaArray.length > nBytesRead + 4){
					if(iSopaVersion < 2){
						iOdd = convertVersion(sopaArray.readByte());
						iEven = convertVersion(sopaArray.readByte());
					}
					else{
						iOdd = sopaArray.readUnsignedByte();
						iEven = sopaArray.readUnsignedByte();
					}
					anglStream.push(iEven);
					anglStream.push(iOdd);
					
					if(iSize == 0 && nCnt != 0){
						if(anglStream[nCnt] == 255)
							iSize = nCnt * 2;
					}
					nCnt += 2;
					
					iVal = int(sopaArray.readShort());
					soundStream.push(iVal);
					nBytesRead += 4;
				}
				nOffset = 0;
				tmpArray = new ByteArray();
				for(iCnt = 0;iCnt < sopaArray.length - nBytesRead;iCnt ++){
					tmpArray.writeByte(sopaArray.readByte());
					nOffset ++;
				}
				iProc = iSize / iOverlap;
				iRem = iSize - iProc;
				iHalf = iSize / 2;
				iRatio *= iSize / 512;
				
				var iSeg:int = iSize * iRateConv;
				
				nHan = new Vector.<Number>(iSeg);
				for(iCnt = 0;iCnt < iSeg;iCnt ++){
					var nRise:Number = Number(iSeg) / 8;
					if(iCnt < nRise)
						nHan[iCnt] = (1.0 - Math.cos(Math.PI * Number(iCnt) / nRise)) / 2.0;
					else if(iSeg - iCnt <= nRise)
						nHan[iCnt] = (1.0 - Math.cos(Math.PI * Number(iSeg - iCnt) / nRise)) / 2.0;
					else
						nHan[iCnt] = 1;
				}	
				
				loopStream = new Vector.<Number>((iBlock + iRem) * CHANNELS * iRateConv);
				realVect = new Vector.<Number>(iSize);
				
				_nSamplesDone = 0;
				
				mySound = new Sound();
				mySound.addEventListener(SampleDataEvent.SAMPLE_DATA,soundDataHandler);
				
				if(sopaArray.length < iChunkSize + 44){
					var myChannel:SoundChannel = new SoundChannel;
					myChannel = mySound.play();
					myChannel.addEventListener(Event.SOUND_COMPLETE,reproductionComplete);	
					SoundMixer.bufferTime = 150;
					_isRunning = true;
				}	
				nBytesLoaded += sopaArray.length - nOffset;
				iTest ++;
				sopaArray.clear();
				sopaArray = new ByteArray();
			}
			else if(iTest > 0){
				sopaArray.position = 0;
				while(nBytesLoaded + sopaArray.length > nBytesRead + 4){
					if(iSopaVersion < 2){
						iOdd = convertVersion(sopaArray.readByte());
						iEven = convertVersion(sopaArray.readByte());
					}
					else{
						iOdd = sopaArray.readUnsignedByte();
						iEven = sopaArray.readUnsignedByte();
					}
					anglStream.push(iEven);
					anglStream.push(iOdd);
					iVal = int(sopaArray.readShort());
					soundStream.push(iVal);
					nBytesRead += 4;
				}
				nOffset = 0;
				tmpArray = new ByteArray();
				for(iCnt = 0;iCnt < sopaArray.length + nBytesLoaded - nBytesRead;iCnt ++){
					tmpArray.writeByte(sopaArray.readByte());
					nOffset ++;
				}
				nBytesLoaded += sopaArray.length - nOffset;
				sopaArray.clear();
				sopaArray = new ByteArray();
			}
		}
		
		private function onSopaLoaded(event:Event):void{
			var iOdd:int,iEven:int,iVal:int;
			
			tmpArray.position = 0;
			for(var iCnt:int = 0;iCnt < nOffset;iCnt ++){
				sopaArray.writeByte(tmpArray.readByte());
			}
			
			sopaLoader.readBytes(sopaArray,nOffset);
			sopaArray.position = 0;
			while(sopaArray.length + nBytesLoaded > nBytesRead + 4){
				if(iSopaVersion < 2){
					iOdd = convertVersion(sopaArray.readByte());
					iEven = convertVersion(sopaArray.readByte());
				}
				else{
					iOdd = sopaArray.readUnsignedByte();
					iEven = sopaArray.readUnsignedByte();
				}
				anglStream.push(iEven);
				anglStream.push(iOdd);
				iVal = int(sopaArray.readShort());
				soundStream.push(iVal);
				nBytesRead += 4;
			}
			sopaArray.clear();
			tmpArray.clear();
			for(iCnt = 0;iCnt < iRem;iCnt ++)
				soundStream.push(0);	
			sopaLoader.close();
			sopaLoader.removeEventListener(ProgressEvent.PROGRESS,onSopaProgress);
			sopaLoader.removeEventListener(Event.COMPLETE,onSopaLoaded);
			
			if(!_isRunning){
				var myChannel:SoundChannel = mySound.play();
				myChannel.addEventListener(Event.SOUND_COMPLETE,reproductionComplete);
				SoundMixer.bufferTime = 150;
				_isRunning = true;
			}			
		}
		
		private function convertVersion(iDir:int):int{
			var iRet:int,nTmp:Number;
			var nVal:Number;
			if(iDir > 72 || iDir < 0)
				iRet = 254;
			else if(iDir == 0)
				iRet = 255;
			else{
				nVal = 72 - Number(iDir);
				
				if(nVal < 36)
					nTmp = 126 - nVal * 16.0 / 36.0;
				else
					nTmp = 127 + (nVal - 36.0) * 16.0 / 36.0;
				iRet = int(nTmp);
			}
			return iRet;
		}
		
		/*	************************** Reproduction **************************	*/
		private function soundDataHandler(event:SampleDataEvent):void{
			var byteArray:ByteArray = new ByteArray();
			var iCnt:int,iBin:int,iMirror:int;
			var iCurrentPos:int = 0;
			var leftReal:Vector.<Number> = new Vector.<Number>(iSize);
			var leftImage:Vector.<Number> = new Vector.<Number>(iSize);
			var rightReal:Vector.<Number> = new Vector.<Number>(iSize);
			var rightImage:Vector.<Number> = new Vector.<Number>(iSize);
			var leftStream:Vector.<Number> = new Vector.<Number>(iSize * iRateConv);
			var rightStream:Vector.<Number> = new Vector.<Number>(iSize * iRateConv);
			var angleVect:Vector.<int> = new Vector.<int>(iHalf);
			var iFrameNum:int = iBlock / iProc;
			var nAtt:Number = 2048.0;
			var nReal:Number,nRealAlias:Number;
			var nImage:Number,nImageAlias:Number;
			var iAngl:int,iAngr:int;
			var iNumber:int;
			var iFreq:int,iFreqImg:int;
			var isClip:Boolean = false;
			
			if(_nSamplesDone > _iSamplesPerChannel - iBlock){
				event.data.writeBytes(byteArray);
				
				_isFinished = true;
				
				mySound.removeEventListener(SampleDataEvent.SAMPLE_DATA,soundDataHandler);
				mySound.removeEventListener(Event.SOUND_COMPLETE,reproductionComplete);
				return;
			}
			for(iCnt = 0;iCnt < iFrameNum;iCnt ++){
				realVect = Vector.<Number>(soundStream.slice(0,iSize));
				while(realVect.length < iSize)
					realVect.push(0);
				soundStream.splice(0,iProc);
				angleVect = anglStream.splice(0,iHalf);
				if(iOverlap == 2)
					anglStream.splice(0,iHalf);
				while(angleVect.length < iHalf)
					angleVect.push(0);
				imageVect = new Vector.<Number>(iSize);
				if(!fastFt(false)){
					_iSamplesPerChannel = _nSamplesDone;
					break;
				}
				else{
					//					Spatial audio rendering
					leftReal[iHalf] = rightReal[iHalf] = realVect[iHalf] * Math.cos(imageVect[iHalf]);
					leftImage[iHalf] = rightImage[iHalf] = realVect[iHalf] * Math.sin(imageVect[iHalf]);
					for(iBin = 0;iBin < iHalf;iBin ++){
						
						iMirror = iSize - iBin;
						iFreq = iBin / iRatio;
						iFreqImg = 511 - iFreq;
						
						nReal = realVect[iBin];
						nImage = imageVect[iBin];
						if(iBin > 0){
							nRealAlias = realVect[iMirror];
							nImageAlias = imageVect[iMirror];
						}
						if(iSopaVersion < 2){
							iAngr = angleVect[iBin];
							iAngl = opposite(iAngr);
						}
						else{
							iAngr = angleVect[iBin];
							iAngl = opposite(iAngr);
						}
						if(iAngl > 255){
							_iSamplesPerChannel = _nSamplesDone;
							break;						
						}
						//						iAngr = modifySector(iAngr,_horizontalAngle,0);
						//						iAngl = modifySector(iAngl,-_horizontalAngle,0);
						
						iAngr = dirArray[iAngr][_horizontalAngle][_verticalAngle];
						iAngl = dirArray[iAngl][71 - _horizontalAngle][_verticalAngle];
						
						if(iBin == 0 || iAngr >= 254){
							leftReal[iBin] = rightReal[iBin] = nReal * Math.cos(nImage);
							leftImage[iBin] = rightImage[iBin] = nReal * Math.sin(nImage);
							if(iBin > 0){
								leftReal[iMirror] = nRealAlias * Math.cos(nImageAlias);
								rightReal[iMirror] = leftReal[iMirror];
								leftImage[iMirror] = nRealAlias * Math.sin(nImageAlias);
								rightImage[iMirror] = leftImage[iMirror];
							}
						}
						else{
							iNumber = 512 * iAngr + iFreq;
							var nPwr:Number = Number(hrtfVect[iNumber]) / nAtt;
							var nPhase:Number = Number(phaseVect[iNumber]) / 10000.0;
							rightReal[iBin] = nReal * nPwr * Math.cos(nImage + nPhase);
							rightImage[iBin] = nReal * nPwr * Math.sin(nImage + nPhase);
							
							iNumber = 512 * iAngr + iFreqImg;
							nPwr = Number(hrtfVect[iNumber]) / nAtt;
							nPhase = Number(phaseVect[iNumber]) / 10000.0;
							rightReal[iMirror] = nRealAlias * nPwr * Math.cos(nImageAlias + nPhase);
							rightImage[iMirror] = nRealAlias * nPwr * Math.sin(nImageAlias + nPhase);
							
							iNumber = 512 * iAngl + iFreq;
							nPwr = Number(hrtfVect[iNumber]) / nAtt;
							nPhase = Number(phaseVect[iNumber]) / 10000.0;
							leftReal[iBin] = nReal * nPwr * Math.cos(nImage + nPhase);
							leftImage[iBin] = nReal * nPwr * Math.sin(nImage + nPhase);
							
							iNumber = 512 * iAngl + iFreqImg;
							nPwr = Number(hrtfVect[iNumber]) / nAtt;
							nPhase = Number(phaseVect[iNumber]) / 10000.0;
							leftReal[iMirror] = nRealAlias * nPwr * Math.cos(nImageAlias + nPhase);
							leftImage[iMirror] = nRealAlias * nPwr * Math.sin(nImageAlias + nPhase);
						}	
						
					}
					realVect = leftReal.slice();
					imageVect = leftImage.slice();
					if(!fastFt(true)){
						_iSamplesPerChannel = _nSamplesDone;
						_isFailed = true;
						break;						
					}
					if(iSampleRate == 22050){
						var nInter:Number = realVect[0];
						for(iBin = 0;iBin < iSize;iBin ++){
							leftStream[iBin * 2] = (nInter + realVect[iBin]) / 2.0 * nHan[iBin * 2];
							leftStream[iBin * 2 + 1] = realVect[iBin] * nHan[iBin * 2 + 1];
							nInter = realVect[iBin];
						}
					}
					else{
						for(iBin = 0;iBin < iSize;iBin ++){
							leftStream[iBin] = realVect[iBin] * nHan[iBin];
						}
					}
					
					realVect = rightReal.slice();
					imageVect = rightImage.slice();
					if(!fastFt(true)){
						_iSamplesPerChannel = _nSamplesDone;
						_isFailed = true;
						break;						
					}
					if(iSampleRate == 22050){
						nInter = realVect[0];
						for(iBin = 0;iBin < iSize;iBin ++){
							rightStream[iBin * 2] = (nInter + realVect[iBin]) / 2.0 * nHan[iBin * 2];
							rightStream[iBin * 2 + 1] = realVect[iBin] * nHan[iBin * 2 + 1];
							nInter = realVect[iBin];
						}
					}
					else{
						for(iBin = 0;iBin < iSize;iBin ++){
							rightStream[iBin] = realVect[iBin] * nHan[iBin];
						}
					}
				}
				for(var iSample:int = iCurrentPos;iSample < iCurrentPos + iSize;iSample ++){
					if(iSampleRate == 22050){
						loopStream[iSample * 4] += leftStream[(iSample - iCurrentPos) * 2] / Number(iOverlap);
						loopStream[iSample * 4 + 1] += rightStream[(iSample - iCurrentPos) * 2] / Number(iOverlap);
						loopStream[iSample * 4 + 2] += leftStream[(iSample - iCurrentPos) * 2 + 1] / Number(iOverlap);
						loopStream[iSample * 4 + 3] += rightStream[(iSample - iCurrentPos) * 2 + 1] / Number(iOverlap);
					}
					else{
						loopStream[iSample * 2] += leftStream[iSample - iCurrentPos] / Number(iOverlap);
						loopStream[iSample * 2 + 1] += rightStream[iSample - iCurrentPos] / Number(iOverlap);
					}
				}
				iCurrentPos += iProc;
			}
			for(iCnt = 0;iCnt < iBlock * CHANNELS * iRateConv;iCnt ++){
				if(loopStream[iCnt] > 32767){
					loopStream[iCnt] = 32767.0;
					isClip = true;
				}
				else if(loopStream[iCnt] < -32768){
					loopStream[iCnt] = -32768.0;
					isClip = true;
				}	
				var nVal:Number = loopStream[iCnt] / 33000.0;
				//				var nVal:Number = loopStream[iCnt];
				byteArray.writeFloat(nVal);
			}
			
			event.data.writeBytes(byteArray);
			
			for(iCnt = 0;iCnt < (iBlock + iRem) * CHANNELS * iRateConv;iCnt ++){
				if(iCnt < iRem * CHANNELS * iRateConv)
					loopStream[iCnt] = loopStream[iCnt + (iBlock * CHANNELS * iRateConv)];
				else
					loopStream[iCnt] = 0.0;
			}
			_nSamplesDone += iBlock;
		}
		
		private function reproductionComplete(event:Event):void{
			//			myTextField.text = "" + sopaStr + " was reproduced";
			_isFinished = true;
			_isRunning = false;
			_nSamplesDone = 0;
			mySound.removeEventListener(SampleDataEvent.SAMPLE_DATA,soundDataHandler);
			mySound.removeEventListener(Event.SOUND_COMPLETE,reproductionComplete);
		}
		
		/************************************************************
		 * 							FFT								*
		 ************************************************************/
		
		public function fastFt(isInv:Boolean):Boolean{
			var sc:Number,f:Number,c:Number,s:Number,t:Number,c1:Number,s1:Number,x1:Number,kyo1:Number;
			var dHan:Number,dPower:Number,dPhase:Number;
			var n:int,j:int,i:int,k:int,ns:int,l1:int,i0:int,i1:int;
			var iInt:int,iTap:int;
			
			iTap = iSize;
			if(iTap <= 0 || (iTap & (iTap - 1)) != 0)
				return false;
			
			if(!isInv){
				for(iInt = 0;iInt < iTap;iInt ++)
				{
					imageVect[iInt] = 0.0;																// Imaginary part 
					dHan = (1.0 - Math.cos((dWpi * Number(iInt)) / Number(iTap))) / 2.0;				// Hanning Window 
					realVect[iInt] *= dHan;																// Real part 
				}
			}	
			
			/********************* Arranging BIT *******************/
			
			n = iTap;	/* NUMBER of DATA */
			sc = Math.PI;
			j = 0;
			for(i = 0;i < n - 1;i ++)
			{
				if(i <= j)
				{
					t = realVect[i];  realVect[i] = realVect[j];  realVect[j] = t;
					t = imageVect[i];   imageVect[i] = imageVect[j];   imageVect[j] = t;
				}
				k = n / 2;
				while(k <= j)
				{
					j = j - k;
					k /= 2;
				}
				j += k;
			}
			
			/********************* MAIN LOOP ***********************/
			ns = 1;
			if(isInv)															// inverse
				f = 1.0;
			else
				f = -1.0;
			while(ns <= n / 2)
			{
				c1 = Math.cos(sc);
				s1 = Math.sin(f * sc);
				c = 1.0;
				s = 0.0;
				for(l1 = 0;l1 < ns;l1 ++)
				{
					for(i0 = l1;i0 < n;i0 += (2 * ns))
					{
						i1 = i0 + ns;
						x1 = (realVect[i1] * c) - (imageVect[i1] * s);
						kyo1 = (imageVect[i1] * c) + (realVect[i1] * s);
						realVect[i1] = realVect[i0] - x1;
						imageVect[i1] = imageVect[i0] - kyo1;
						realVect[i0] = realVect[i0] + x1;
						imageVect[i0] = imageVect[i0] + kyo1;
					}
					t = (c1 * c) - (s1 * s);
					s = (s1 * c) + (c1 * s);
					c = t;
				}
				ns *= 2;
				sc /= 2.0;
			}
			if(!isInv)
			{
				for(iInt = 0;iInt < iTap;iInt ++)
				{
					realVect[iInt] /= Number(iTap);
					imageVect[iInt] /= Number(iTap);
					dPower = Math.sqrt(realVect[iInt] * realVect[iInt] + imageVect[iInt] * imageVect[iInt]);
					dPhase = Math.atan2(imageVect[iInt],realVect[iInt]);
					realVect[iInt] = dPower;
					imageVect[iInt] = dPhase;
				}
			}
			return true;
		}
		
		/****************************************************************
		 * 				Flip direction (right to left)					*
		 ****************************************************************/
		
		private function opposite(right:int):int{
			if(right == 0 || right >= 253)
				return(right);
			else if(right < 9){
				if(right == 1)
					return(right);
				else
					return(10 - right);
			}
			else if(right < 25){
				if(right == 9)
					return(right);
				else
					return(34 - right);				
			}
			else if(right < 49){
				if(right == 25)
					return(right);
				else
					return(74 - right);
			}
			else if(right < 79){
				if(right == 49)
					return(right);
				else
					return(128 - right);
			}
			else if(right < 111){
				if(right == 79)
					return(right);
				else
					return(190 - right);
			}
			else if(right < 127){
				if(right == 111)
					return(right);
				else
					return(15 + right);
			}
			else if(right < 143){
				if(right == 142)
					return(right);
				else
					return(right - 15);
			}
			else if(right < 175){
				if(right == 174)
					return(right);
				else
					return(316 - right);
			}
			else if(right < 205){
				if(right == 204)
					return(right);
				else
					return(378 - right);
			}
			else if(right < 229){
				if(right == 228)
					return(right);
				else
					return(432 - right);
			}
			else if(right < 245){
				if(right == 244)
					return(right);
				else
					return(472 - right);
			}
			else{
				if(right == 252)
					return(right);
				else
					return(496 - right);
			}
		}
		
		private function initCoord(iSector:int):Vector3D{
			var coord:Vector3D = new Vector3D;
			var nPan:Number,nTilt:Number;
			var nUnitLong:Number;
			var nUnitHori:Number;
			var nHoriAngl:Number;
			var nUnitLat:Number = Math.PI / 12;
			
			if(iSector >= 127)
				nUnitLat *= -1;
			
			if(iSector == 0){
				coord.x = coord.z = 0;
				coord.y = 1;
			}
			else if(iSector == 253){
				coord.x = coord.z = 0;
				coord.y = -1;
			}
			else if(iSector < 9 || iSector >= 245){
				nUnitLong = Math.PI / 4.0;
				nUnitHori = Math.cos(nUnitLat * 5);
				
				if(iSector < 9){
					coord.y = Math.sin(nUnitLat * 5);
					nHoriAngl = nUnitLong * (Number(iSector) - 1) - Math.PI;
				}
				else{
					coord.y = Math.sin(nUnitLat * -5);
					nHoriAngl = nUnitLong * (252 - Number(iSector));
				}
				
				coord.x = nUnitHori * Math.sin(nHoriAngl);
				coord.z = nUnitHori * Math.cos(nHoriAngl);
			}
			else if(iSector < 25 || iSector >= 229){
				nUnitLong = Math.PI / 8;
				nUnitHori = Math.cos(nUnitLat * 4);
				
				if(iSector < 25){
					coord.y = Math.sin(nUnitLat * 4);
					nHoriAngl = nUnitLong * (Number(iSector) - 9) - Math.PI;
				}
				else{
					coord.y = Math.sin(nUnitLat * -4);
					nHoriAngl = nUnitLong * (244 - Number(iSector));
				}
				
				coord.x = nUnitHori * Math.sin(nHoriAngl);
				coord.z = nUnitHori * Math.cos(nHoriAngl);
			}
			else if(iSector < 49 || iSector >= 205){
				nUnitLong = Math.PI / 12;
				nUnitHori = Math.cos(nUnitLat * 3);
				
				if(iSector < 49){
					coord.y = Math.sin(nUnitLat * 3);
					nHoriAngl = nUnitLong * (Number(iSector) - 25) - Math.PI;
				}
				else{
					coord.y = Math.sin(nUnitLat * -3);
					nHoriAngl = nUnitLong * (228 - Number(iSector));
				}
				
				coord.x = nUnitHori * Math.sin(nHoriAngl);
				coord.z = nUnitHori * Math.cos(nHoriAngl);
			}
			else if(iSector < 79 || iSector >= 175){
				nUnitLong = Math.PI / 15;
				nUnitHori = Math.cos(nUnitLat * 2);
				
				if(iSector < 79){
					coord.y = Math.sin(nUnitLat * 2);
					nHoriAngl = nUnitLong * (Number(iSector) - 49) - Math.PI;
				}
				else{
					coord.y = Math.sin(nUnitLat * -2);
					nHoriAngl = nUnitLong * (204 - Number(iSector));
				}
				
				coord.x = nUnitHori * Math.sin(nHoriAngl);
				coord.z = nUnitHori * Math.cos(nHoriAngl);
			}
			else if(iSector < 111 || iSector >= 143){
				nUnitLong = Math.PI / 16;
				nUnitHori = Math.cos(nUnitLat);
				
				if(iSector < 111){
					coord.y = Math.sin(nUnitLat);
					nHoriAngl = nUnitLong * (Number(iSector) - 79) - Math.PI;
				}
				else{
					coord.y = Math.sin(-nUnitLat);
					nHoriAngl = nUnitLong * (174 - Number(iSector));
				}
				
				coord.x = nUnitHori * Math.sin(nHoriAngl);
				coord.z = nUnitHori * Math.cos(nHoriAngl);
			}
			else{
				nUnitLong = Math.PI / 16;
				nUnitHori = 1.0;
				coord.y = 0;
				
				if(iSector < 127)
					nHoriAngl = nUnitLong * (Number(iSector) - 111) - Math.PI;
				else
					nHoriAngl = nUnitLong * (142 - Number(iSector));
				
				coord.x = nUnitHori * Math.sin(nHoriAngl);
				coord.z = nUnitHori * Math.cos(nHoriAngl);
			}
			return coord;
		}
		
		private function modifySector(iSector:int,nPan:Number,nTilt:Number):int{
			var iNewSect:int;
			var nUnitHori:Number;
			var nHoriAngl:Number;
			
			if(iSector > 253)
				return iSector;
			
			if(iSector != 0 && iSector != 253)
				nHoriAngl= Math.atan2(coordVect[iSector].x,coordVect[iSector].z) + nPan;
			
			if(iSector == 0 || iSector == 253)
				nUnitHori = 0;
			else if(iSector < 9 || iSector >= 245){
				nUnitHori = Math.cos(Math.PI * 5 / 12);
			}
			else if(iSector < 25 || iSector >= 229){
				nUnitHori = Math.cos(Math.PI / 3);
			}
			else if(iSector < 49 || iSector >= 205){
				nUnitHori = Math.cos(Math.PI / 4);
			}
			else if(iSector < 79 || iSector >= 175){
				nUnitHori = Math.cos(Math.PI / 6);
			}
			else if(iSector < 111 || iSector >= 143){
				nUnitHori = Math.cos(Math.PI / 12);
			}
			else
				nUnitHori = 1.0;
			
			var myCoord:Vector3D = new Vector3D();
			myCoord.x = nUnitHori * Math.sin(nHoriAngl);
			myCoord.z = nUnitHori * Math.cos(nHoriAngl);
			myCoord.y = coordVect[iSector].y;
			
			if(nTilt == 0 || myCoord.z == 0)
				iNewSect = calcSector(myCoord);
			else{
				var nVerAngl:Number = Math.atan2(myCoord.y,myCoord.z) + nTilt;
				var nUnitVer:Number = Math.sqrt(myCoord.z * myCoord.z + myCoord.y * myCoord.y);
				myCoord.z = nUnitVer * Math.cos(nVerAngl);
				myCoord.y = nUnitVer * Math.sin(nVerAngl);
				iNewSect = calcSector(myCoord);
			}			
			return iNewSect;
		}
		
		private function calcSector(coor:Vector3D):int{
			var iSector:int;
			var nHoriAngl:Number;
			
			if(coor.y >= Math.sin(Math.PI * 11 / 24))
				return 0;
			else if(coor.y <= -Math.sin(Math.PI * 11 / 24))
				return 253;
			else
				nHoriAngl = Math.atan2(coor.x,coor.z);
			
			if(coor.y >= Math.sin(Math.PI * 3 / 8)){
				if(nHoriAngl < 0)
					nHoriAngl += dWpi;
				iSector = int(1 + nHoriAngl / (Math.PI / 4));
			}
			else if(coor.y <= -Math.sin(Math.PI * 3 / 8))
				iSector = int(249.0 - nHoriAngl / (Math.PI / 4));
			else if(coor.y >= Math.sin(Math.PI * 7 / 24)){
				if(nHoriAngl < 0)
					nHoriAngl += dWpi;
				iSector = int(9.0 + nHoriAngl / (Math.PI / 8));
			}
			else if(coor.y <= -Math.sin(Math.PI * 7 / 24))
				iSector = int(237.0 - nHoriAngl / (Math.PI / 8));
			else if(coor.y >= Math.sin(Math.PI * 5 / 24)){
				if(nHoriAngl < 0)
					nHoriAngl += dWpi;
				iSector = int(25 + nHoriAngl / (Math.PI / 12));
			}
			else if(coor.y <= -Math.sin(Math.PI * 5 / 24))
				iSector = int(217.0 - nHoriAngl / (Math.PI / 12));
			else if(coor.y >= Math.sin(Math.PI / 8)){
				if(nHoriAngl < 0)
					nHoriAngl += dWpi;
				iSector = int(49 + nHoriAngl / (Math.PI / 15));
			}
			else if(coor.y <= -Math.sin(Math.PI / 8))
				iSector = int(190.0 - nHoriAngl / (Math.PI / 15));
			else if(coor.y >= Math.sin(Math.PI / 24)){
				if(nHoriAngl < 0)
					nHoriAngl += dWpi;
				iSector = int(79 + nHoriAngl / (Math.PI / 16));
			}
			else if(coor.y <= -Math.sin(Math.PI / 24))
				iSector = int(159.0 - nHoriAngl / (Math.PI / 16));
			else if(nHoriAngl < 0)
				iSector = 127 - nHoriAngl / (Math.PI / 16);
			else
				iSector = 111 + nHoriAngl / (Math.PI / 16);
			
			return iSector;
		}
		
		private function setPanAxis(tiltAngle:Number):Vector3D{
			var panAxis:Vector3D = new Vector3D;
			
			panAxis.z = Math.sin(-tiltAngle);
			panAxis.y = Math.cos(-tiltAngle);
			panAxis.x = 0;
			return panAxis;
		}		
		
		private function checkHeader(dataArray:ByteArray):Boolean{
			var iRIFF:Vector.<int> = Vector.<int>([82,73,70,70]);					// RIFF
			var iSOPA:Vector.<int> = Vector.<int>([83,79,80,65,102,109,116]);		// SOPA fmt
			var iVect:Vector.<int> = new Vector.<int>();
			var iVal:int;
			
			dataArray.position = 0;
			for(var iCnt:int = 0;iCnt < 4;iCnt ++){
				iVect.push(dataArray.readUnsignedByte());
			}
			if(iVect.toString() != iRIFF.toString()){
				return false;
			}
			dataArray.position = 8;
			iVect = new Vector.<int>();
			for(iCnt = 0;iCnt < 7;iCnt ++){
				iVect.push(dataArray.readUnsignedByte());
			}
			if(iVect.toString() != iSOPA.toString()){
				return false;
			}
			dataArray.position = 16;
			iVal = dataArray.readByte();
			if(iVal != 16)
				return false;
			else
				iByte = 2;
			dataArray.position = 20;
			iVal = dataArray.readByte();
			if(iVal != 1)
				return false;
			dataArray.position = 22;
			iOverlap = dataArray.readByte();
			if(iOverlap != 2 && iOverlap != 4)
				return false;
			
//			dataArray.endian = Endian.LITTLE_ENDIAN;
			dataArray.position = 24;
			iSampleRate = dataArray.readShort();
			
			dataArray.position = 36;
			iVersion = new Vector.<int>();
			for(iCnt = 0;iCnt < 4;iCnt ++){
				iVersion.push(dataArray.readUnsignedByte());
			}
			
			dataArray.position = 40;
			iChunkSize = dataArray.readInt();
			
			return true;
		}		
	}

}