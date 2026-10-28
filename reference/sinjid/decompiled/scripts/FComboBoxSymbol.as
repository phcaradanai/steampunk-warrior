function FComboBoxClass()
{
   _global._popUpLevel = _global._popUpLevel != undefined ? _global._popUpLevel + 1 : 20000;
   this.superHolder = _root.createEmptyMovieClip("superHolder" + _popUpLevel,_popUpLevel);
   var testContainer = this.superHolder.createEmptyMovieClip("testCont",20000);
   var testBox = testContainer.attachMovie("FBoundingBoxSymbol","boundingBox_mc",0);
   if(testBox._name == undefined)
   {
      this.superHolder.removeMovieClip();
      this.superHolder = this._parent.createEmptyMovieClip("superHolder" + _popUpLevel,_popUpLevel);
   }
   else
   {
      testContainer.removeMovieClip();
   }
   if(this.rowCount == undefined)
   {
      this.rowCount = 8;
      this.editable = false;
   }
   this.itemSymbol = "FComboBoxItemSymbol";
   this.init();
   this.permaScrollBar = false;
   this.proxyBox_mc.gotoAndStop(1);
   this.width = this._width;
   this.height = this.proxyBox_mc._height * this._yscale / 100;
   var i = 0;
   while(i < this.labels.length)
   {
      this.addItem(this.labels[i],this.data[i]);
      i++;
   }
   this.lastSelected = 0;
   this.selectItem(0);
   this._xscale = this._yscale = 100;
   this.opened = false;
   this.setSize(this.width);
   this.highlightTop(false);
   if(this.changeHandler.length > 0)
   {
      this.setChangeHandler(this.changeHandler);
   }
   this.onUnload = function()
   {
      this.superHolder.removeMovieClip();
   };
   this.setSelectedIndex(0,false);
   this.value = "";
   this.focusEnabled = true;
   this.changeFlag = false;
}
FComboBoxClass.prototype = new FScrollSelectListClass();
Object.registerClass("FComboBoxSymbol",FComboBoxClass);
FComboBoxClass.prototype.modelChanged = function(eventObj)
{
   super.modelChanged(eventObj);
   var event = eventObj.event;
   if(event == "addRows" || event == "deleteRows")
   {
      var diff = eventObj.lastRow - eventObj.firstRow + 1;
      var mode = event != "addRows" ? -1 : 1;
      var len = this.getLength();
      var lenBefore = len - mode * diff;
      if(this.rowCount > lenBefore || this.rowCount > len)
      {
         this.invalidate("setSize");
      }
      if(this.getSelectedIndex() == undefined)
      {
         this.setSelectedIndex(0,false);
      }
   }
   else if(event == "updateAll")
   {
      this.invalidate("setSize");
   }
};
FComboBoxClass.prototype.removeAll = function()
{
   if(!this.enable)
   {
      return undefined;
   }
   super.removeAll();
   if(this.editable)
   {
      this.value = "";
   }
   this.invalidate("setSize");
};
FComboBoxClass.prototype.setSize = function(w)
{
   if(w == undefined || typeof w != "number" || w <= 0 || !this.enable)
   {
      return undefined;
   }
   this.proxyBox_mc._width = w;
   this.container_mc.removeMovieClip();
   this.measureItmHgt();
   this.container_mc = this.superHolder.createEmptyMovieClip("container",3);
   this.container_mc.tabChildren = false;
   this.setPopUpLocation(this.container_mc);
   this.container_mc.attachMovie("FBoundingBoxSymbol","boundingBox_mc",0);
   this.boundingBox_mc = this.container_mc.boundingBox_mc;
   this.boundingBox_mc.component = this;
   this.registerSkinElement(this.boundingBox_mc.boundingBox,"background");
   this.proxyBox_mc._height = this.itmHgt;
   this.numDisplayed = Math.min(this.rowCount,this.getLength());
   if(this.numDisplayed < 3)
   {
      this.numDisplayed = Math.min(3,this.getLength());
   }
   this.height = this.numDisplayed * (this.itmHgt - 2) + 2;
   super.setSize(w,this.height);
   this.attachMovie("DownArrow","downArrow",10);
   this.downArrow._y = 0;
   this.downArrow._width = this.itmHgt;
   this.downArrow._height = this.itmHgt;
   this.downArrow._x = this.proxyBox_mc._width - this.downArrow._width;
   this.setEditable(this.editable);
   this.container_mc._visible = this.opened;
   this.highlightTop(false);
   this.fader = this.superHolder.attachMovie("FBoundingBoxSymbol","faderX",4);
   this.registerSkinElement(this.fader.boundingBox,"background");
   this.fader._width = this.width;
   this.fader._height = this.height;
   this.fader._visible = false;
};
FComboBoxClass.prototype.setDataProvider = function(dp)
{
   super.setDataProvider(dp);
   this.invalidate("setSize");
   this.setSelectedIndex(0);
};
FComboBoxClass.prototype.getValue = function()
{
   if(this.editable)
   {
      return this.fLabel_mc.getLabel();
   }
   return super.getValue();
};
FComboBoxClass.prototype.getRowCount = function()
{
   return this.rowCount;
};
FComboBoxClass.prototype.setRowCount = function(count)
{
   this.rowCount = this.getLength() <= count ? count : Math.max(count,3);
   this.setSize(this.width);
   var len = this.getLength();
   if(len - this.getScrollPosition() < this.rowCount)
   {
      this.setScrollPosition(len - Math.min(this.rowCount,len));
      this.invalidate("updateControl");
   }
};
FComboBoxClass.prototype.setEditable = function(editableFlag)
{
   if(!this.enable)
   {
      return undefined;
   }
   this.editable = editableFlag;
   if(!this.editable)
   {
      this.onPress = this.pressHandler;
      this.useHandCursor = false;
      this.trackAsMenu = true;
      this.attachMovie("FComboBoxItemSymbol","fLabel_mc",5,{controller:this,itemNum:-1});
      this.fLabel_mc.onRollOver = undefined;
      this.fLabel_mc.setSize(this.width - this.itmHgt + 1,this.itmHgt);
      this.topLabel = this.getSelectedItem();
      this.fLabel_mc.drawItem(this.topLabel,false);
      this.highlightTop(false);
   }
   else
   {
      this.attachMovie("FLabelSymbol","fLabel_mc",5);
      this.fLabel_txt = this.fLabel_mc.labelField;
      this.fLabel_txt.type = "input";
      this.fLabel_txt._x = 4;
      this.fLabel_txt.onSetFocus = this.onLabelFocus;
      this.fLabel_mc.setSize(this.width - this.itmHgt - 3);
      delete this.onPress;
      this.fLabel_txt.onKillFocus = function()
      {
         this._parent._parent.myOnKillFocus();
      };
      this.fLabel_mc.setLabel(this.value);
      this.fLabel_txt.onChanged = function()
      {
         this._parent._parent.findInputText();
      };
      this.downArrow.onPress = this.buttonPressHandler;
      this.downArrow.useHandCursor = false;
      this.downArrow.trackAsMenu = true;
   }
};
FComboBoxClass.prototype.setEnabled = function(enabledFlag)
{
   enabledFlag = !(enabledFlag == undefined || typeof enabledFlag != "boolean") ? enabledFlag : true;
   super.setEnabled(enabledFlag);
   this.registerSkinElement(this.boundingBox_mc.boundingBox,"background");
   this.proxyBox_mc.gotoAndStop(!this.enable ? "disabled" : "enabled");
   this.downArrow.gotoAndStop(!this.enable ? 3 : 1);
   if(this.editable)
   {
      this.fLabel_txt.type = !enabledFlag ? "dynamic" : "input";
      this.fLabel_txt.selectable = enabledFlag;
   }
   else if(enabledFlag)
   {
      this.fLabel_mc.drawItem(this.topLabel,false);
      this.setSelectedIndex(this.getSelectedIndex(),false);
   }
   this.fLabel_mc.setEnabled(this.enable);
   this.fLabel_txt.onSetFocus = !enabledFlag ? undefined : this.onLabelFocus;
};
FComboBoxClass.prototype.setSelectedIndex = function(index, flag)
{
   super.setSelectedIndex(index,flag);
   if(!this.editable)
   {
      this.topLabel = this.getSelectedItem();
      this.fLabel_mc.drawItem(this.topLabel,false);
   }
   else
   {
      this.value = flag == undefined ? this.getSelectedItem().label : "";
      this.fLabel_mc.setLabel(this.value);
   }
   this.invalidate("updateControl");
};
FComboBoxClass.prototype.setValue = function(value)
{
   if(this.editable)
   {
      this.fLabel_mc.setLabel(value);
      this.value = value;
   }
};
FComboBoxClass.prototype.pressHandler = function()
{
   this.focusRect.removeMovieClip();
   if(this.enable)
   {
      if(!this.opened)
      {
         this.onMouseUp = this.releaseHandler;
      }
      else
      {
         this.onMouseUp = undefined;
      }
      this.changeFlag = false;
      if(!this.focused)
      {
         this.pressFocus();
         this.clickFilter = !this.editable ? true : false;
      }
      if(!this.clickFilter)
      {
         this.openOrClose(!this.opened);
      }
      else
      {
         this.clickFilter = false;
      }
   }
};
FComboBoxClass.prototype.clickHandler = function(itmNum)
{
   if(!this.focused)
   {
      if(this.editable)
      {
         this.fLabel_txt.onKillFocus = undefined;
      }
      this.pressFocus();
   }
   super.clickHandler(itmNum);
   this.selectionHandler(itmNum);
   this.onMouseUp = this.releaseHandler;
};
FComboBoxClass.prototype.highlightTop = function(flag)
{
   if(!this.editable)
   {
      this.fLabel_mc.drawItem(this.topLabel,flag);
   }
};
FComboBoxClass.prototype.myOnSetFocus = function()
{
   super.myOnSetFocus();
   this.fLabel_mc.highlight_mc.gotoAndStop("enabled");
   this.highlightTop(true);
};
FComboBoxClass.prototype.drawFocusRect = function()
{
   this.drawRect(-2,-2,this.width + 4,this._height + 4);
};
FComboBoxClass.prototype.myOnKillFocus = function()
{
   if(Selection.getFocus().indexOf("labelField") != -1)
   {
      return undefined;
   }
   super.myOnKillFocus();
   delete this.fLabel_txt.onKeyDown;
   this.openOrClose(false);
   this.highlightTop(false);
};
FComboBoxClass.prototype.setPopUpLocation = function(mcRef)
{
   mcRef._x = this._x;
   var point = {x:this._x,y:this._y + this.proxyBox_mc._height};
   this._parent.localToGlobal(point);
   mcRef._parent.globalToLocal(point);
   mcRef._x = point.x;
   mcRef._y = point.y;
   if(this.height + mcRef._y >= Stage.height)
   {
      this.upward = true;
      mcRef._y = point.y - this.height - this.proxyBox_mc._height;
   }
   else
   {
      this.upward = false;
   }
};
FComboBoxClass.prototype.openOrClose = function(flag)
{
   if(this.getLength() == 0)
   {
      return undefined;
   }
   this.setPopUpLocation(this.container_mc);
   if(this.lastSelected != -1 && (this.lastSelected < this.topDisplayed || this.lastSelected > this.topDisplayed + this.numDisplayed))
   {
      super.moveSelBy(this.lastSelected - this.getSelectedIndex());
   }
   !flag ? this.downArrow.gotoAndStop(1) : this.downArrow.gotoAndStop(2);
   if(flag == this.opened)
   {
      return undefined;
   }
   this.highlightTop(!flag);
   this.fadeRate = this.styleTable.popUpFade.value;
   if(!flag || this.fadeRate == undefined || this.fadeRate == 0)
   {
      this.opened = this.container_mc._visible = flag;
      return undefined;
   }
   this.setPopUpLocation(this.fader);
   this.time = 0;
   this.const = 85 / Math.sqrt(this.fadeRate);
   this.fader._alpha = 85;
   this.container_mc._visible = this.fader._visible = true;
   this.onEnterFrame = function()
   {
      this.fader._alpha = 100 - (this.const * Math.sqrt(++this.time) + 15);
      if(this.time >= this.fadeRate)
      {
         this.fader._visible = false;
         delete this.onEnterFrame;
         this.opened = true;
      }
   };
};
FComboBoxClass.prototype.fireChange = function()
{
   this.lastSelected = this.getSelectedIndex();
   if(!this.editable)
   {
      this.topLabel = this.getSelectedItem();
      this.fLabel_mc.drawItem(this.topLabel,true);
   }
   else
   {
      this.value = this.getSelectedItem().label;
      this.fLabel_mc.setLabel(this.value);
   }
   this.executeCallback();
};
FComboBoxClass.prototype.releaseHandler = function()
{
   var onCombo = this.boundingBox_mc.hitTest(_root._xmouse,_root._ymouse);
   if(this.changeFlag)
   {
      if(onCombo)
      {
         this.fireChange();
      }
      this.openOrClose(!this.opened);
   }
   else if(onCombo)
   {
      this.openOrClose(false);
   }
   else
   {
      this.onMouseDown = function()
      {
         if(!this.boundingBox_mc.hitTest(_root._xmouse,_root._ymouse) && !this.hitTest(_root._xmouse,_root._ymouse))
         {
            this.onMouseDown = undefined;
            this.openOrClose(false);
         }
      };
   }
   this.changeFlag = false;
   this.onMouseUp = undefined;
   clearInterval(this.dragScrolling);
   this.dragScrolling = undefined;
};
FComboBoxClass.prototype.moveSelBy = function(itemNum)
{
   if(itemNum != 0)
   {
      super.moveSelBy(itemNum);
      if(this.editable)
      {
         this.setValue(this.getSelectedItem().label);
      }
      if(!this.opened)
      {
         if(this.changeFlag && !this.isSelected(this.lastSelected))
         {
            this.fireChange();
         }
      }
   }
};
FComboBoxClass.prototype.myOnKeyDown = function()
{
   if(!this.focused)
   {
      return undefined;
   }
   if(this.editable && Key.isDown(13))
   {
      this.setValue(this.fLabel_mc.getLabel());
      this.executeCallback();
      this.openOrClose(false);
   }
   else if((Key.isDown(13) || Key.isDown(32) && !this.editable) && this.opened)
   {
      if(this.getSelectedIndex() != this.lastSelected)
      {
         this.fireChange();
      }
      this.openOrClose(false);
      this.fLabel_txt.hscroll = 0;
   }
   super.myOnKeyDown();
};
FComboBoxClass.prototype.findInputText = function()
{
   if(!this.editable)
   {
      super.findInputText();
   }
};
FComboBoxClass.prototype.onLabelFocus = function()
{
   this._parent._parent.tabFocused = false;
   this._parent._parent.focused = true;
   this.onKeyDown = function()
   {
      this._parent._parent.myOnKeyDown();
   };
   Key.addListener(this);
};
FComboBoxClass.prototype.buttonPressHandler = function()
{
   this._parent.pressHandler();
};
