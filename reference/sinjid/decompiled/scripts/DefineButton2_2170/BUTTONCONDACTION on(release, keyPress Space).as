on(release, keyPress "<Space>"){
   _root.engb -= _root.engcost;
   if(_root.engb < 0)
   {
      _root.engb = 0;
   }
   _root.lifeb = _root.hero1life;
   _root.manab = _root.hero1mana;
   _root.pause = false;
   _root.clearstage = false;
   _root.reload = true;
   _root.gotoAndStop("reload");
}
