onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char.stepper) && Key.isDown(32) && _root.pause == false && _root.talking != true && _root.clearstage == false && spacedown != true)
   {
      if(_root.portallevel[0] > 20)
      {
         _root.clearstage = true;
         spacedown = true;
         _root.NewStage("up",10.5,10);
         this.gotoAndPlay("change");
      }
      else
      {
         spacedown = true;
         _root.TalkBox.SpeakerText = "Information";
         _root.TalkBox.TalkText = speak;
         _root.TalkBox._visible = true;
         _root.pause = true;
         _root.talking = true;
         _root.TalkBox.gotoAndPlay(1);
      }
   }
}
