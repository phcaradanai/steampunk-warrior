// Analysis-only unity-gain analyser in the original output path.
window.reaAudioAnalysers=[];
const reaOriginalConnect=AudioNode.prototype.connect;
const reaContextAnalysers=new WeakMap();
AudioNode.prototype.connect=function(destination,...args){
  if(destination===this.context.destination){
    let analyser=reaContextAnalysers.get(this.context);
    if(!analyser){
      analyser=this.context.createAnalyser();analyser.fftSize=2048;
      reaContextAnalysers.set(this.context,analyser);window.reaAudioAnalysers.push(analyser);
      Reflect.apply(reaOriginalConnect,analyser,[destination]);
    }
    Reflect.apply(reaOriginalConnect,this,[analyser,...args]);
    return destination;
  }
  return Reflect.apply(reaOriginalConnect,this,[destination,...args]);
};
window.reaAudioRMS=()=>({
  nodes:window.reaAudioAnalysers.length,
  contexts:window.reaAudioAnalysers.map(a=>a.context.state),
  rms:Math.max(0,...window.reaAudioAnalysers.map(a=>{
    const samples=new Float32Array(a.fftSize);a.getFloatTimeDomainData(samples);
    return Math.sqrt(samples.reduce((sum,x)=>sum+x*x,0)/samples.length);
  })),
});
