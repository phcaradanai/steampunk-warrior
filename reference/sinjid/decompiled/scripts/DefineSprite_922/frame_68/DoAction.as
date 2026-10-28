_root.meet = false;
_root.midfight = false;
_root.cleargrid = false;
_root.gotoAndPlay(label);
stopAllSounds();
if(prevsound < 3)
{
   prevsound++;
}
else
{
   prevsound = 1;
}
_root.playSound("Battle" + prevsound);
