on(release){
   _root.inventory.saved.play();
   datasave = new Array();
   datasave = ["strb","speedb","lifemaxb","manamaxb","expb","engmaxb","gold","phydmgb","magdmgb","phydefb","magdefb","shdphydefb","shdmagdefb","shdptsb","shddmgb","level","playername","newobjective","Helmet","Suit","Weapon","Shield","manapots","lifepots","skillpts","expmaxb","rests","ninjaav","classname","classtype"];
   _root.user.data.stats = new Array();
   _root.user.data.itemstats = new Array();
   _root.user.data.skill = new Array();
   for(i in datasave)
   {
      _root.user.data.stats[i] = _root[datasave[i]];
   }
   for(i in _root.skill)
   {
      _root.user.data.skill[i] = _root.skill[i];
   }
   for(i in _root.itemstats)
   {
      _root.user.data.itemstats[i] = _root.itemstats[i];
   }
   _root.user.data.p1 = _root.portallevel[0];
   _root.user.data.p2 = _root.portallevel[1];
   _root.user.data.p3 = _root.portallevel[2];
   _root.user.data.life = _root.lifeb;
   _root.user.data.mana = _root.manab;
   _root.user.data.eng = _root.engb;
   _root.user.flush();
   play();
}
