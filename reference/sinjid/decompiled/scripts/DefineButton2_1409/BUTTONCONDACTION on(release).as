on(release){
   if(_root.gold >= 5)
   {
      _root.gold -= 5;
      _root.manab += 40;
      manabar.gotoAndPlay("up");
      if(_root.manab > _root.manamaxb)
      {
         _root.manab = _root.manamaxb;
      }
      manabar._width = _root.manab / _root.manamaxb * manabar.widthkeep;
   }
}
