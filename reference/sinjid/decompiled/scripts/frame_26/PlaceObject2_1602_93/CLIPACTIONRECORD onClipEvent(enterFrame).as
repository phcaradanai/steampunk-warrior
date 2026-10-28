onClipEvent(enterFrame){
   if(this.hitTest(_root.grid.char))
   {
      _root.grid.char.pointer.gotoAndPlay("left");
   }
}
