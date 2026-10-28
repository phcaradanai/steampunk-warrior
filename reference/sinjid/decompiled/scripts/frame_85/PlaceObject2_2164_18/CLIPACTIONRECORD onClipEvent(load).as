onClipEvent(load){
   function goldUP()
   {
      if(_root.goldup > 0)
      {
         _root.goldup--;
         _root.gold++;
      }
   }
   function expUP()
   {
      if(_root.expup > 0)
      {
         _root.expup--;
         _root.expb++;
         if(_root.expb == _root.expmaxb)
         {
            _root.statpts++;
            _root.skillpts++;
            _root.lifemaxb += 5;
            _root.manamaxb += 5;
            _root.engmaxb += 3;
            _root.level++;
            i = 1;
            while(i < 20)
            {
               if(_root.level / 5 == i)
               {
                  _root.strb += 2;
                  _root.speedb += 2;
                  _root.skillpts++;
                  _root.bonusplus._visible = true;
               }
               i++;
            }
            _root.expb = 0;
            _root.expmaxb = 50 * _root.level;
            _root.expb += _root.expup;
            if(_root.expb >= _root.expmaxb)
            {
               _root.expb = _root.expmaxb - 1;
            }
            _root.gotoAndStop("levelup");
         }
      }
   }
}
