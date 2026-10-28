onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char.stepper) && Key.isDown(32) && _root.pause == false && _root.talking != true && _root.clearstage == false)
   {
      if(_root.portallevel[0] > 20)
      {
         _root.clearstage = true;
         stopAllSounds();
         _root.clearstage = true;
         _root.cleargrid = true;
         removeMovieClip("TalkBox");
         removeMovieClip("inventory");
         removeMovieClip("objectives");
         removeMovieClip("blackout");
         this.gotoAndPlay("change");
         _root.gotoAndPlay("theend");
      }
      else
      {
         _root.TalkBox.SpeakerText = "Information";
         _root.TalkBox.TalkText = speak;
         _root.TalkBox._visible = true;
         _root.pause = true;
         _root.talking = true;
         _root.TalkBox.gotoAndPlay(1);
      }
   }
}
