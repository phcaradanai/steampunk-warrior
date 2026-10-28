onClipEvent(enterFrame){
   if(this.person.hitTest(_root.grid.char))
   {
      this.gotoAndPlay("yellow");
   }
}
