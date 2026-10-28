on(release){
   if(_root.midfight == false && _root.playermove[_root.turnnum] == "hero1" && _root.Skill[skilllabel] > 0 && _root.hero1mana >= manareq && _root.Weapon != "None" && _root.enemy1life + _root.enemy2life > 0)
   {
      _root.Fight(["Skill" + skilllabel]);
      _root.midfight = true;
      _root.turnnum++;
      if(_root.turnnum == 4)
      {
         _root.turnnum = 0;
      }
   }
}
