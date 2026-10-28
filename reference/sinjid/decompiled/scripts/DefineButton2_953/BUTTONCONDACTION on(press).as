on(press){
   _root.inventory.explainbox._visible = false;
   _root.inventory["slot" + _root.slotnum].gotoAndStop(_root.itempick);
   _root.itemhold = _root.itemstats[_root.slotnum];
   _root.itemstats[_root.slotnum] = _root.itempick;
   _root.itempick = _root.itemhold;
   _root.inventory.itemmouse.gotoAndStop(_root.itempick);
   _root.slotnum = undefined;
}
