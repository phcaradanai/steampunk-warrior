on(release){
   if(_root.midfight == false && _root.playermove[_root.turnnum] == "hero1" && _root.manapots > 0 && _root.enemy1life + _root.enemy2life > 0)
   {
      _root.Fight("healmana");
      _root.midfight = true;
      _root.turnnum++;
      _root.manapots--;
      if(_root.turnnum == 4)
      {
         _root.turnnum = 0;
      }
   }
}
