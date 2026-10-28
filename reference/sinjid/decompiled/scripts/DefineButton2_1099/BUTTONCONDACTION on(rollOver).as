on(rollOver){
   itemlist = ["Drink"];
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
      sellprice = 3;
   }
}
