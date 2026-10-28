_root.engb -= _root.engrate;
_root.expup += Math.ceil(_root.exprate * 2);
if(_root.engb <= 0)
{
   _root.engb = 0;
   _root.endtrain = true;
   _root.blackout.play();
   stop();
}
_root.engbar._width = _root.engb / _root.engmaxb * _root.engbar.widthkeep;
