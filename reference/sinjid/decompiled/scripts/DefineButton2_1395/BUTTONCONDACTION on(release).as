on(release){
   if(_root.gold >= 15)
   {
      _root.gold -= 15;
      _root.manapots += 1;
      manapotmc.gotoAndPlay(2);
   }
}
