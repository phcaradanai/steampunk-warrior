onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char))
   {
      if(Key.isDown(32) && _root.pause == false)
      {
         _root.clearstage = true;
         _root.NewStage("right",2,Math.ceil(_root.grid.char._y / 30));
         this.gotoAndPlay("change");
      }
   }
}
