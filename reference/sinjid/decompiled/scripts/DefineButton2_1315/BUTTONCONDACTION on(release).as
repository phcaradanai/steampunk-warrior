on(release){
   if(_root.gold >= foodcost)
   {
      tellTarget(mealset)
      {
         gotoAndPlay(2);
      }
      _root.gold -= foodcost;
      _root.lifeb += foodlife;
      lifebar.gotoAndPlay("up");
      if(_root.lifeb > _root.lifemaxb)
      {
         _root.lifeb = _root.lifemaxb;
      }
      lifebar._width = _root.lifeb / _root.lifemaxb * lifebar.widthkeep;
      _root.engb += foodeng;
      engbar.gotoandplay("up");
      if(_root.engb > _root.engmaxb)
      {
         _root.engb = _root.engmaxb;
      }
      engbar._width = _root.engb / _root.engmaxb * engbar.widthkeep;
      _root.manab += foodmana;
      manabar.gotoandplay("up");
      if(_root.manab > _root.manamaxb)
      {
         _root.manab = _root.manamaxb;
      }
      manabar._width = _root.manab / _root.manamaxb * manabar.widthkeep;
   }
}
