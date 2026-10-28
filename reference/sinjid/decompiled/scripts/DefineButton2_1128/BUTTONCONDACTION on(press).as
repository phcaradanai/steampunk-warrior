on(press){
   if(itemcheck == true && sellprice != "")
   {
      _root.itempick = "None";
      _root.inventory.itemmouse.gotoAndStop(_root.itempick);
      _root.gold += sellprice;
      sellprice = "";
   }
}
