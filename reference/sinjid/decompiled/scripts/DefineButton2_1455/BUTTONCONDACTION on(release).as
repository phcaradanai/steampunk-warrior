on(release){
   _root.exprate = 20;
   _root.engrate = 10;
   level = 3;
   if(_root.engb > 0)
   {
      if(_root.itempick == "None" && _root.hold != true)
      {
         gotoAndStop(1);
         sellprice = "";
         for(i in _root.BodyParts)
         {
            _root.grid.char.movement[_root.BodyParts[i]].gotoAndStop(_root.Suit);
         }
         with(_root.grid.char.movement)
         {
            head.gotoAndStop(_root.Helmet);
         }
         _root.walkmenu.engbar._width = _root.engb / _root.engmaxb * _root.walkmenu.engbar.widthkeep;
         _root.walkmenu.lifebar._width = _root.lifeb / _root.lifemaxb * _root.walkmenu.lifebar.widthkeep;
         _root.walkmenu.manabar._width = _root.manab / _root.manamaxb * _root.walkmenu.manabar.widthkeep;
         _root.walkmenu.manabar._width = _root.manab / _root.manamaxb * _root.walkmenu.manabar.widthkeep;
         _root.walkmenu.lifebar._width = _root.lifeb / _root.lifemaxb * _root.walkmenu.lifebar.widthkeep;
         _parent.inventory._visible = false;
         _root.pause = false;
      }
      _root.encounter.portaltype = "Training Room";
      _root.encounter.level = level;
      _root.encounter.label = "TRAIN" + [level];
      _root.bgstage = "Arena";
      _root.encounter.play();
      _root.meet = true;
      _root.pause = true;
   }
}
