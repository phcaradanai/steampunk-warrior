onClipEvent(enterFrame){
   if(_root.goldup > 0)
   {
      goldUP();
      goldUP();
      goldUP();
      goldUP();
      goldUP();
      goldUP();
      goldUP();
      goldUP();
   }
   else if(_root.expup > 0)
   {
      expUP();
      expUP();
      expUP();
      expUP();
      expUP();
      expUP();
      expUP();
   }
   else
   {
      _root.conbut._visible = true;
   }
}
