on(release){
   if(_root.meet == false && _root.talking != true && _root.pause == false)
   {
      _root.inventory.gotoAndStop("Skills");
      _root.grid.char.movement.gotoAndStop(1);
      _root.inventory._visible = true;
      _root.pause = true;
   }
}
