onClipEvent(enterFrame){
   if(this.hitTest(_root.grid.char.stepper) && _root.portallevel[level] <= 5)
   {
      this.gotoAndPlay("yellow");
   }
}
