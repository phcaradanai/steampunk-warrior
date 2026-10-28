onClipEvent(keyDown){
   if(this.person.hitTest(_root.grid.char))
   {
      if(Key.isDown(32) && _root.pause == false && _root.talking != true && _root.clearstage == false)
      {
         _root.TalkBox.SpeakerText = persontype;
         _root.TalkBox.TalkText = speak;
         _root.TalkBox._visible = true;
         _root.pause = true;
         _root.talking = true;
         _root.TalkBox.gotoAndPlay(1);
      }
   }
}
