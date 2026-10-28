onClipEvent(load){
   this.setSelectedIndex(_root.soundset);
   if(_root.soundon == "Off")
   {
      played = false;
   }
   else
   {
      played = true;
   }
}
