on(release, keyPress "<Space>"){
   if(_root.itempick == "None" && _root.hold != true)
   {
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
      gotoAndStop(1);
      _root.pause = false;
   }
}
