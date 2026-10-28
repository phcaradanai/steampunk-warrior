if(_root.engb > 0)
{
   _root.engb--;
}
else if(_root.lifeb > 1)
{
   _root.lifeb--;
   if(_root.manab > 1)
   {
      _root.manab--;
   }
}
_root.walkmenu.manabar._width = _root.manab / _root.manamaxb * _root.walkmenu.manabar.widthkeep;
_root.walkmenu.lifebar._width = _root.lifeb / _root.lifemaxb * _root.walkmenu.lifebar.widthkeep;
_root.walkmenu.engbar._width = _root.engb / _root.engmaxb * _root.walkmenu.engbar.widthkeep;
