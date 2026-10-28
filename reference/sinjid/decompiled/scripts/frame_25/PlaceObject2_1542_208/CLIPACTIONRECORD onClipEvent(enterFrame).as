onClipEvent(enterFrame){
   if(this.person.hitTest(_root.grid.char))
   {
      this.gotoAndPlay("yellow");
   }
   if(_root.clearstage == true)
   {
      removeMovieClip(this);
   }
   if(this._y > _root.charything)
   {
      this.swapDepths(20000 + objectnum);
   }
   else
   {
      this.swapDepths(0 + objectnum);
   }
}
