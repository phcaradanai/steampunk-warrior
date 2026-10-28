onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char.stepper) && _root.clearstage == false)
   {
      if(Key.isDown(32) && _root.pause == false)
      {
         if(_root.portallevel[level] > 5)
         {
            _root.TalkBox.SpeakerText = "Information";
            _root.TalkBox.TalkText = speak;
            _root.TalkBox._visible = true;
            _root.pause = true;
            _root.talking = true;
            _root.TalkBox.gotoAndPlay(1);
         }
         else
         {
            _root.encounter.portaltype = "Dark Rift";
            _root.encounter.level = _root.portallevel[level];
            _root.encounter.label = _root.portal3[_root.portallevel[level]];
            _root.bgstage = _root.portalstages[random(_root.portalstages.length)];
            _root.encounter.play();
            _root.portallevel[level] += 1;
            _root.meet = true;
            _root.pause = true;
         }
      }
   }
}
