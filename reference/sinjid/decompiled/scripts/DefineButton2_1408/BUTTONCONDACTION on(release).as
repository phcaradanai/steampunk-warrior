on(release){
   if(_root.gold >= 10)
   {
      _root.gold -= 10;
      _root.lifeb += 40;
      lifebar.gotoAndPlay("up");
      if(_root.lifeb > _root.lifemaxb)
      {
         _root.lifeb = _root.lifemaxb;
      }
      lifebar._width = _root.lifeb / _root.lifemaxb * lifebar.widthkeep;
   }
}
