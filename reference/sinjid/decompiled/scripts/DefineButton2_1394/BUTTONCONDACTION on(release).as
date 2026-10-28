on(release){
   if(_root.gold >= 25)
   {
      _root.gold -= 25;
      _root.lifepots += 1;
      lifepotmc.gotoAndPlay(2);
   }
}
