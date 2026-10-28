onClipEvent(load){
   if(_root.enemy1life == 0)
   {
      this._visible = false;
   }
   gotoAndStop(35);
   target = "enemy1";
   typeoftarget = "herotarget";
   otherpointer = "pointer2";
}
