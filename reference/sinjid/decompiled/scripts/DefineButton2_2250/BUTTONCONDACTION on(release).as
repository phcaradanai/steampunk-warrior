on(release){
   stopAllSounds();
   _root.portallevel[_root.levelsave]--;
   manab = 5;
   lifeb = 5;
   engb = 5;
   _root.pause = false;
   _root.clearstage = false;
   _root.reload = true;
   _root.gotoAndStop("reload");
}
