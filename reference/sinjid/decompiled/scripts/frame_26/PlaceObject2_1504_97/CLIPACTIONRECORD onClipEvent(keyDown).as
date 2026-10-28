onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char.stepper) && spacedown != true)
   {
      if(Key.isDown(32))
      {
         spacedown = true;
         _root.clearstage = true;
         _root.NewStage("up",10.5,9.5);
         this.gotoAndPlay("change");
      }
   }
}
