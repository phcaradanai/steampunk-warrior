onClipEvent(enterFrame){
   if(_root.midfight == false && _root.playermove[_root.turnnum] == "hero1")
   {
      if(_root.enemy1life > 0)
      {
         _root.pointer1._visible = true;
      }
      if(_root.enemy2life > 0)
      {
         _root.pointer2._visible = true;
      }
      this._visible = false;
   }
   else
   {
      this._visible = true;
      _root.pointer2._visible = false;
      _root.pointer1._visible = false;
   }
}
