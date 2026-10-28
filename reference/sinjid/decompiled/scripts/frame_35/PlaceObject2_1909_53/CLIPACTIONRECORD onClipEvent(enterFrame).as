onClipEvent(enterFrame){
   if(_root.hero2life == 0)
   {
      this._visible = false;
   }
   else
   {
      this._visible = true;
   }
   if(_root.midfight == false && _root.playermove[_root.turnnum] == "hero2")
   {
      if(_root.hero2life > 0)
      {
         if(_root.enemy1life + _root.enemy2life > 0)
         {
            _root.Fight(attacks[random(numofmoves)]);
            _root.midfight = true;
         }
      }
      _root.turnnum++;
      if(_root.turnnum == 4)
      {
         _root.turnnum = 0;
      }
   }
}
