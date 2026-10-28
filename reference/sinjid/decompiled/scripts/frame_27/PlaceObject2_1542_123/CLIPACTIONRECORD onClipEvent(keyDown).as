onClipEvent(keyDown){
   if(this.person.hitTest(_root.grid.char))
   {
      if(Key.isDown(32) && _root.pause == false && _root.talking != true && _root.clearstage == false)
      {
         speak = speak1;
         i = 4;
         while(i < 12)
         {
            _root.SearchItem("White Leaves",true);
            if(_root.Searched == true)
            {
               _root.GetItem("Medicine",0);
               _root.Searched = false;
               speak = speak2;
            }
            i++;
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
