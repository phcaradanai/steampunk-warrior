on(release){
   if(_root.midfight == false && _root.playermove[_root.turnnum] == "hero1" && _root.lifepots > 0 && _root.enemy1life + _root.enemy2life > 0)
   {
      _root.Fight("heallife");
      _root.midfight = true;
      _root.turnnum++;
      _root.lifepots--;
      if(_root.turnnum == 4)
      {
         _root.turnnum = 0;
      }
   }
}
