on(release){
   if(_root.gold >= 20)
   {
      _root.gold -= 20;
      _root.manab += 60;
      _root.lifeb += 60;
      lifebar.gotoAndPlay("up");
      if(_root.lifeb > _root.lifemaxb)
      {
         _root.lifeb = _root.lifemaxb;
      }
      lifebar._width = _root.lifeb / _root.lifemaxb * lifebar.widthkeep;
   }
   manabar.gotoAndPlay("up");
   if(_root.manab > _root.manamaxb)
   {
      _root.manab = _root.manamaxb;
   }
   manabar._width = _root.manab / _root.manamaxb * manabar.widthkeep;
}
