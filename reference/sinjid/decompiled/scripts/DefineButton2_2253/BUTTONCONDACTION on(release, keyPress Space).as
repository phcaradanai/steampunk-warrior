on(release, keyPress "<Space>"){
   _root.lifeb = _root.hero1life;
   _root.pause = false;
   _root.clearstage = false;
   _root.reload = true;
   _root.gotoAndStop(_root.save_stage);
}
