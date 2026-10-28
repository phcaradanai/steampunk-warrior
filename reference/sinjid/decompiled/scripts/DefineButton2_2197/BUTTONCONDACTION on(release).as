on(release){
   if(_root.statpts > 0)
   {
      _root.conbut._visible = true;
      _root.statpts--;
      trace(classtype);
      trace(_root[classtype][3]);
      _root.speedb += _root[classtype][3];
      _root.engmaxb += 2;
   }
}
