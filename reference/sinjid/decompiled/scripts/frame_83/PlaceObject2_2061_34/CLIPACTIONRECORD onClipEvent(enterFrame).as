onClipEvent(enterFrame){
   if(_root.midfight == false && _root.playermove[_root.turnnum] == "enemy2")
   {
      if(_root.enemy2life > 0)
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
