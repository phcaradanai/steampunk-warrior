on(rollOver){
   pricegain = 1.3;
   itemlist = ["Weapon","Suit","Shield","Head Gear"];
   itemcheck = false;
   for(i in itemlist)
   {
      if(_root.item[_root.itempick][1] == itemlist[i])
      {
         itemcheck = true;
      }
   }
   if(itemcheck == true)
   {
      sellprice = 0;
      if(_root.item[_root.itempick][1] == "Head Gear")
      {
         pricegain = 0.7;
      }
      if(_root.item[_root.itempick][1] == "Shield")
      {
         pricegain = 0.4;
      }
      if(_root.item[_root.itempick][1] == "Suit")
      {
         pricegain *= 1.8;
      }
      valuework = 0;
      i = 2;
      while(i < 13)
      {
         valuework += _root.item[_root.itempick][i] * pricegain;
         i++;
      }
      sellprice = Math.round(valuework);
   }
}
