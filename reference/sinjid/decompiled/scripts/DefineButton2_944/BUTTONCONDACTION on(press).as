on(press){
   if(_root.item[_root.itempick][1] != "Required Item")
   {
      _root.itempick = "None";
      _root.inventory.itemmouse.gotoAndStop(_root.itempick);
   }
}
