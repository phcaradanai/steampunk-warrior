onClipEvent(enterFrame){
   _root.soundset = lastSelected;
   _root.soundon = this.Labels[lastSelected];
   if(_root.soundon == "Off")
   {
      stopAllSounds();
      played = false;
   }
   if(_root.soundon == "On")
   {
      if(played == false)
      {
         _root.playSound("Dream");
         played = true;
      }
   }
}
