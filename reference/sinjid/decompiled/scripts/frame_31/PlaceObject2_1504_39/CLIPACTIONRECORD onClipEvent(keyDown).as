onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char.stepper) && spacedown != true)
   {
      if(Key.isDown(32))
      {
         spacedown = true;
         _root.clearstage = true;
         _root.NewStage("down",10.5,6);
         this.gotoAndPlay("change");
      }
   }
}
