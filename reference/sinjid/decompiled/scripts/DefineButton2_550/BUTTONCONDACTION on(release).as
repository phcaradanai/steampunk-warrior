on(release){
   if(_root.meet == false && _root.talking != true && _root.manapots > 0)
   {
      _root.manab += 80;
      _root.manapots -= 1;
      _root.playSound("potion");
      manapotmc.gotoAndPlay(2);
      manabar.gotoAndPlay("up");
      if(_root.manab > _root.manamaxb)
      {
         _root.manab = _root.manamaxb;
      }
      manabar._width = _root.manab / _root.manamaxb * manabar.widthkeep;
   }
}
