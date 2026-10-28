onClipEvent(enterFrame){
   if(_root.pause == false)
   {
      if(Key.isDown(39) || Key.isDown(68))
      {
         this.gotoAndStop("right");
      }
      else if(Key.isDown(37) || Key.isDown(65))
      {
         this.gotoAndStop("left");
      }
      if((Key.isDown(38) || Key.isDown(87)) && !Key.isDown(39) && !Key.isDown(37) && !Key.isDown(65) && !Key.isDown(68))
      {
         this.gotoAndStop("up");
      }
      else if((Key.isDown(40) || Key.isDown(83)) && !Key.isDown(39) && !Key.isDown(37) && !Key.isDown(65) && !Key.isDown(68))
      {
         this.gotoAndStop("down");
      }
   }
}
