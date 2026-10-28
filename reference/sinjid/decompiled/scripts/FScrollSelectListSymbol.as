function FScrollSelectListClass()
{
   this.init();
}
FScrollSelectListClass.prototype = new FSelectableListClass();
FScrollSelectListClass.prototype.getScrollPosition = function()
{
   return this.topDisplayed;
};
FScrollSelectListClass.prototype.setScrollPosition = function(pos)
{
   if(this.enable)
   {
      pos = Math.min(pos,this.getLength() - this.numDisplayed);
      pos = Math.max(pos,0);
      this.scrollBar_mc.setScrollPosition(pos);
   }
};
FScrollSelectListClass.prototype.setAutoHideScrollBar = function(flag)
{
   this.permaScrollBar = !flag;
   this.setSize(this.width,this.height);
};
FScrollSelectListClass.prototype.setEnabled = function(enabledFlag)
{
   super.setEnabled(enabledFlag);
   this.scrollBar_mc.setEnabled(this.enable);
};
FScrollSelectListClass.prototype.setSize = function(w, h)
{
   var pos = this.getScrollPosition();
   super.setSize(w,h);
   if(this.scrollBar_mc != undefined)
   {
      this.removed = true;
   }
   this.scrollBar_mc = undefined;
   this.initScrollBar();
   this.setScrollPosition(pos);
};
FScrollSelectListClass.prototype.modelChanged = function(eventObj)
{
   super.modelChanged(eventObj);
   this.invalidate("initScrollBar");
};
FScrollSelectListClass.prototype.initScrollBar = function()
{
   if(!this.permaScrollBar && this.getLength() <= this.numDisplayed)
   {
      if(this.removed)
      {
         this.scrollBar_mc.removeMovieClip();
         this.scrollBar_mc = undefined;
         this.scrollOffset = undefined;
         this.invalidate("setSize");
      }
   }
   else
   {
      if(this.scrollBar_mc == undefined)
      {
         this.container_mc.attachMovie("FScrollBarSymbol","scrollBar_mc",3000,{hostStyle:this.styleTable});
         this.scrollBar_mc = this.container_mc.scrollBar_mc;
         this.scrollBar_mc.setChangeHandler("scrollHandler",this);
         this.scrollBar_mc.setSize(this.height);
         this.scrollBar_mc._x = this.width - this.scrollBar_mc._width;
         this.scrollBar_mc._y = 0;
         this.scrollBar_mc.setLargeScroll(this.numDisplayed - 1);
         this.scrollOffset = this.scrollBar_mc._width;
         this.invalidate("setSize");
      }
      this.scrollBar_mc.setScrollProperties(this.numDisplayed,0,this.getLength() - this.numDisplayed);
   }
};
FScrollSelectListClass.prototype.scrollHandler = function(scrollBar)
{
   var pos = scrollBar.getScrollPosition();
   this.topDisplayed = pos;
   if(this.lastPosition != pos)
   {
      this.updateControl();
   }
   this.lastPosition = pos;
};
FScrollSelectListClass.prototype.clickHandler = function(itmNum)
{
   super.clickHandler(itmNum);
   if(this.dragScrolling == undefined && this.scrollBar_mc != undefined)
   {
      this.dragScrolling = setInterval(this,"dragScroll",15);
   }
};
FScrollSelectListClass.prototype.releaseHandler = function()
{
   clearInterval(this.dragScrolling);
   this.dragScrolling = undefined;
   super.releaseHandler();
};
FScrollSelectListClass.prototype.dragScroll = function()
{
   clearInterval(this.dragScrolling);
   if(this.container_mc._ymouse < 0)
   {
      this.setScrollPosition(this.getScrollPosition() - 1);
      this.selectionHandler(0);
      this.scrollInterval = Math.max(25,-23.8 * (- this.container_mc._ymouse) + 500);
      this.dragScrolling = setInterval(this,"dragScroll",this.scrollInterval);
   }
   else if(this.container_mc._ymouse > (this.itmHgt - 2) * this.numDisplayed)
   {
      this.setScrollPosition(this.getScrollPosition() + 1);
      this.selectionHandler(this.numDisplayed - 1);
      this.scrollInterval = Math.max(25,-23.8 * Math.abs(this.container_mc._ymouse - (this.itmHgt - 2) * this.numDisplayed - 2) + 500);
      this.dragScrolling = setInterval(this,"dragScroll",this.scrollInterval);
   }
   else
   {
      this.dragScrolling = setInterval(this,"dragScroll",15);
   }
};
FScrollSelectListClass.prototype.myOnKeyDown = function()
{
   if(this.focused)
   {
      this.keyCodes = new Array(40,38,34,33,36,35);
      this.keyIncrs = new Array(1,-1,this.numDisplayed - 1,- (this.numDisplayed - 1),- this.getLength(),this.getLength());
      var i = 0;
      while(i < this.keyCodes.length)
      {
         if(Key.isDown(this.keyCodes[i]))
         {
            this.moveSelBy(this.keyIncrs[i]);
            return undefined;
         }
         i++;
      }
      this.findInputText();
   }
};
FScrollSelectListClass.prototype.findInputText = function()
{
   var tmpCode = Key.getAscii();
   if(tmpCode >= 33 && tmpCode <= 126)
   {
      this.findString(String.fromCharCode(tmpCode));
   }
};
FScrollSelectListClass.prototype.findString = function(str)
{
   if(this.getLength() == 0)
   {
      return undefined;
   }
   var itemNum = this.getSelectedIndex();
   var jump = 0;
   var i = itemNum + 1;
   while(i != itemNum)
   {
      var itmStr = this.getItemAt(i).label.substring(0,str.length);
      if(str == itmStr || str.toUpperCase() == itmStr.toUpperCase())
      {
         var jump = i - itemNum;
         break;
      }
      if(i >= this.getLength() - 1)
      {
         i = -1;
      }
      i++;
   }
   if(jump != 0)
   {
      this.moveSelBy(jump);
   }
};
