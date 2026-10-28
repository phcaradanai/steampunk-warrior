onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char))
   {
      if(Key.isDown(32) && _root.pause == false && _root.talking != true && _root.clearstage == false && _root.meet == false && _root.talking != true)
      {
         _root.grid.char.movement.gotoAndStop(1);
         _root.inventory.gotoAndStop(inventorytype);
         _root.inventory._visible = true;
         _root.pause = true;
         _root.hold = true;
      }
   }
}
