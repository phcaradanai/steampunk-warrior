onClipEvent(enterFrame){
   if(this.hitTest(_root.cloud._x,this._y))
   {
      if(this._alpha > 0)
      {
         this._alpha -= 5;
      }
   }
   else if(this._alpha < 50)
   {
      this._alpha += 5;
   }
}
