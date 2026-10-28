on(release){
   if(_root.meet == false && _root.talking != true && _root.lifepots > 0)
   {
      _root.lifeb += 80;
      _root.lifepots -= 1;
      _root.playSound("potion");
      lifepotmc.gotoAndPlay(2);
      lifebar.gotoAndPlay("up");
      if(_root.lifeb > _root.lifemaxb)
      {
         _root.lifeb = _root.lifemaxb;
      }
      lifebar._width = _root.lifeb / _root.lifemaxb * lifebar.widthkeep;
   }
}
