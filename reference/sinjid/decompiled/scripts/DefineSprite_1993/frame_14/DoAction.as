if(_root.hero1life <= 0)
{
   if(_root.midfight == false)
   {
      _root.midfight = true;
      gotoAndPlay(23);
   }
   else
   {
      gotoAndPlay(13);
   }
}
else if(_root.enemy1life + _root.enemy2life <= 0 || _root.endtrain == true)
{
   if(_root.midfight == false)
   {
      _root.midfight = true;
      gotoAndPlay(15);
   }
   else
   {
      gotoAndPlay(13);
   }
}
else
{
   gotoAndStop(12);
}
if(_root.enemy1life <= 0)
{
   _root.herotarget = "enemy2";
   _root.pointer1._visible = false;
   _root.pointer2.gotoAndStop("choosen");
}
if(_root.enemy2life <= 0)
{
   _root.herotarget = "enemy1";
   _root.pointer2._visible = false;
   _root.pointer1.gotoAndStop("choosen");
}
