onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char.stepper) && spacedown != true)
   {
      if(Key.isDown(32))
      {
         spacedown = true;
         _root.clearstage = true;
         _root.NewStage("down",14,5.5);
         this.gotoAndPlay("change");
      }
   }
}
