onClipEvent(load){
   this.swapDepths(100);
   if(_root.reload == true)
   {
      _root.reload = false;
      buildGrid();
      initializeChar(_root.save_x,_root.save_y);
      _root.game.char.x = _root.save_x;
      _root.game.char.y = _root.save_y;
      _root.grid.char._x = _root.save_x;
      _root.grid.char._y = _root.save_y;
      _root.gotoAndStop(_root.save_stage);
   }
}
