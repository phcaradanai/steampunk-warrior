onClipEvent(enterFrame){
   if(_root.midfight == false && _root.playermove[_root.turnnum] == "enemy1")
   {
      if(_root.enemy1life > 0)
      {
         _root.Fight(attacks[random(numofmoves)]);
         _root.midfight = true;
      }
      _root.turnnum++;
      if(_root.turnnum == 4)
      {
         _root.turnnum = 0;
      }
   }
}
