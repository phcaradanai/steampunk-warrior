on(release){
   if(_root.skill[skilllabel] < 10 && _root.skillpts > 0 && _root.level >= levelreq && _root.skill[6] != 0)
   {
      _root.skillpts--;
      _root.skill[skilllabel]++;
      _root.playSound("skillup");
      gotoAndPlay(14);
      _root.inventory.skillbox.gotoAndStop("UP");
      _root.inventory.skillbox.gotoAndStop(["Skill" + skilllabel]);
   }
   else
   {
      _root.playSound("no");
   }
}
