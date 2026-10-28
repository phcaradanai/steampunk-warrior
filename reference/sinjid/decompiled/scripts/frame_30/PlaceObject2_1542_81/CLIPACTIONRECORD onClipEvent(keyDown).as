onClipEvent(keyDown){
   if(this.person.hitTest(_root.grid.char))
   {
      if(Key.isDown(32) && _root.pause == false && _root.talking != true && _root.clearstage == false)
      {
         if(_root.moon_q == false)
         {
            _root.SearchNone();
            if(_root.Searched == true)
            {
               _root.Searched == false;
               _root.GetItem("Mendo\'s Ring",0);
               speak = speak1;
               _root.moon_q = true;
            }
            else
            {
               speak = speak3;
            }
         }
         else
         {
            speak = speak2;
         }
         _root.TalkBox.SpeakerText = persontype;
         _root.TalkBox.TalkText = speak;
         _root.TalkBox._visible = true;
         _root.pause = true;
         _root.talking = true;
         _root.TalkBox.gotoAndPlay(1);
      }
   }
}
