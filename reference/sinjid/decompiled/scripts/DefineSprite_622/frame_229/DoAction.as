if(_root.engb == 0)
{
   if(_root.lifeb > 1)
   {
      _root.lifeb--;
      if(_root.manab > 1)
      {
         _root.manab--;
      }
   }
}
_root.walkmenu.manabar._width = _root.manab / _root.manamaxb * _root.walkmenu.manabar.widthkeep;
_root.walkmenu.lifebar._width = _root.lifeb / _root.lifemaxb * _root.walkmenu.lifebar.widthkeep;
