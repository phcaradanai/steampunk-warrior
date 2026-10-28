onClipEvent(enterFrame){
   if(_root.midfight == false && _root.playermove[_root.turnnum] == "enemy1")
   {
      if(_root.enemy1life > 0)
      {
         if(_root.hero2life > 0)
         {
            randtarg = random(2) + 1;
            _root.enemytarget = "hero" + randtarg;
         }
         else
         {
            _root.enemytarget = "hero1";
         }
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
