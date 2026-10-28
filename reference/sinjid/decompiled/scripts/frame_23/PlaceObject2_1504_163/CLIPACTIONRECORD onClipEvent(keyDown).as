onClipEvent(keyDown){
   if(this.hitTest(_root.grid.char.stepper))
   {
      if(Key.isDown(32) && _root.pause == false)
      {
         if(_root.portallevel[level] <= 20)
         {
            _root.encounter.portaltype = "Human Gateway";
            _root.encounter.level = [_root.portallevel[level]];
            _root.encounter.label = _root.portal1[_root.portallevel[level]];
            _root.bgstage = _root.portalstages[random(_root.portalstages.length)];
            _root.encounter.play();
            _root.portallevel[level]++;
            _root.meet = true;
            _root.pause = true;
         }
         else
         {
            _root.TalkBox.SpeakerText = "Information";
            _root.TalkBox.TalkText = speak;
            _root.TalkBox._visible = true;
            _root.pause = true;
            _root.talking = true;
            _root.TalkBox.gotoAndPlay(1);
         }
      }
   }
}
