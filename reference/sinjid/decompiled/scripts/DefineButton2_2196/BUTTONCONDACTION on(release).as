on(release){
   if(_root.statpts > 0)
   {
      _root.conbut._visible = true;
      _root.statpts--;
      _root.strb += _root[classtype][2];
      _root.engmaxb += 2;
   }
}
