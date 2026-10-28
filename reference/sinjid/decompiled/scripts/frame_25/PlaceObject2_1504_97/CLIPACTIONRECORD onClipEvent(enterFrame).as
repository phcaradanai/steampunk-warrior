onClipEvent(enterFrame){
   if(this.hitTest(_root.grid.char.stepper))
   {
      this.gotoAndPlay("yellow");
   }
}
