on(press){
   if(_root.item[_root.itempick][1] == "None")
   {
      _root.inventory.explainbox._visible = false;
      _root.RemoveItem(_root.itemstats[_root.slotnum],"Helmet");
      _root.inventory["slot" + _root.slotnum].gotoAndStop(_root.itempick);
      itemhold = _root.itemstats[_root.slotnum];
      _root.itemstats[_root.slotnum] = _root.itempick;
      _root.itempick = itemhold;
      _root.inventory.itemmouse.gotoAndStop(_root.itempick);
   }
   else if(_root.item[_root.itempick][1] == "Head Gear" && _root.strb >= _root.item[_root.itempick][14])
   {
      _root.inventory.explainbox._visible = false;
      _root.RemoveItem(_root.itemstats[_root.slotnum],"Helmet");
      _root.inventory["slot" + _root.slotnum].gotoAndStop(_root.itempick);
      itemhold = _root.itemstats[_root.slotnum];
      _root.itemstats[_root.slotnum] = _root.itempick;
      _root.itempick = itemhold;
      _root.inventory.itemmouse.gotoAndStop(_root.itempick);
      _root.EquipItem(_root.itemstats[_root.slotnum],"Helmet");
   }
   else
   {
      _root.playSound("no");
   }
}
