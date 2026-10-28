on(release){
   if(_root.statpts > 0)
   {
      _root.conbut._visible = true;
      _root.statpts--;
      _root.lifemaxb += _root[classtype][0];
   }
}
