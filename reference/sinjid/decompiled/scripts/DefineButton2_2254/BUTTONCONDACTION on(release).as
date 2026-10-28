on(release){
   stopAllSounds();
   _root.cleargrid = false;
   datasave = new Array();
   datasave = ["strb","speedb","lifemaxb","manamaxb","expb","engmaxb","gold","phydmgb","magdmgb","phydefb","magdefb","shdphydefb","shdmagdefb","shdptsb","shddmgb","level","playername","newobjective","Helmet","Suit","Weapon","Shield","manapots","lifepots","skillpts","expmaxb","rests","ninjaav","classname","classtype"];
   if(user.data.stats[strb] != undefined)
   {
      for(i in datasave)
      {
         _root[datasave[i]] = user.data.stats[i];
      }
      for(i in _root.skill)
      {
         _root.skill[i] = user.data.skill[i];
      }
      for(i in _root.itemstats)
      {
         _root.itemstats[i] = user.data.itemstats[i];
      }
      _root.portallevel[0] = user.data.p1;
      _root.portallevel[1] = user.data.p2;
      _root.portallevel[2] = user.data.p3;
      lifeb = user.data.life;
      manab = user.data.mana;
      engb = user.data.eng;
      user.flush();
      _root.pause = false;
      gotoAndPlay(20);
   }
}
