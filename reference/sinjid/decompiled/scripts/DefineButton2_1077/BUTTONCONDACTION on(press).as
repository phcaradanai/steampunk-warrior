on(press){
   if(_root.itempick == "None" && _root.gold >= cost)
   {
      _root.gold -= cost;
      _root.inventory.explainbox._visible = false;
      _root.itempick = _root.itemstats[_root.slotnum];
      _root.inventory.itemmouse.gotoAndStop(_root.itempick);
   }
}
