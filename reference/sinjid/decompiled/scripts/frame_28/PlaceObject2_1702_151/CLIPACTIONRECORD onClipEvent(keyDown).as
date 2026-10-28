onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char.stepper) && Key.isDown(32) && _root.pause == false && _root.talking != true && _root.clearstage == false)
   {
      _root.SearchItem("Mendo\'s Ring",true);
      if(_root.Searched == true)
      {
         _root.skillpts++;
         _root.Searched = false;
         _root.TalkBox.SpeakerText = "Information";
         _root.TalkBox.TalkText = speak;
         _root.TalkBox._visible = true;
         _root.pause = true;
         _root.talking = true;
         _root.TalkBox.gotoAndPlay(1);
      }
   }
}
