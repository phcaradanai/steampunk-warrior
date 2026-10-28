function FSelectableListClass()
{
   this.init();
}
FSelectableListClass.prototype = new FUIComponentClass();
FSelectableListClass.prototype.init = function()
{
   super.init();
   this.enable = true;
   this.selected = new Array();
   this.topDisplayed = this.numDisplayed = 0;
   this.lastSelected = 0;
   this.tabChildren = false;
   if(this._name != undefined)
   {
      this.dataProvider = new DataProviderClass();
      this.dataProvider.addView(this);
   }
};
FSelectableListClass.prototype.addItemAt = function(index, label, data)
{
   if(index < 0 || !this.enable)
   {
      return undefined;
   }
   this.dataProvider.addItemAt(index,{label:label,data:data});
};
FSelectableListClass.prototype.addItem = function(label, data)
{
   if(!this.enable)
   {
      return undefined;
   }
   this.dataProvider.addItem({label:label,data:data});
};
FSelectableListClass.prototype.removeItemAt = function(index)
{
   this.selectHolder = this.getSelectedIndex();
   var item = this.getItemAt(index);
   this.dataProvider.removeItemAt(index);
   return item;
};
FSelectableListClass.prototype.removeAll = function()
{
   this.dataProvider.removeAll();
};
FSelectableListClass.prototype.replaceItemAt = function(index, newLabel, newData)
{
   this.dataProvider.replaceItemAt(index,{label:newLabel,data:newData});
};
FSelectableListClass.prototype.sortItemsBy = function(fieldName, order)
{
   this.lastSelID = this.dataProvider.getItemID(this.lastSelected);
   this.dataProvider.sortItemsBy(fieldName,order);
};
FSelectableListClass.prototype.getLength = function()
{
   return this.dataProvider.getLength();
};
FSelectableListClass.prototype.getSelectedIndex = function()
{
   for(var uniqueID in this.selected)
   {
      var tmpInd = this.selected[uniqueID].sIndex;
      if(tmpInd != undefined)
      {
         return tmpInd;
      }
   }
};
FSelectableListClass.prototype.getSelectedItem = function()
{
   return this.getItemAt(this.getSelectedIndex());
};
FSelectableListClass.prototype.getItemAt = function(index)
{
   return this.dataProvider.getItemAt(index);
};
FSelectableListClass.prototype.getEnabled = function()
{
   return this.enable;
};
FSelectableListClass.prototype.getValue = function()
{
   var item = this.getSelectedItem();
   return item.data != undefined ? item.data : item.label;
};
FSelectableListClass.prototype.setSelectedIndex = function(index, flag)
{
   if(index >= 0 && index < this.getLength() && this.enable)
   {
      this.clearSelected();
      this.selectItem(index,true);
      this.lastSelected = index;
      this.invalidate("updateControl");
      if(flag != false)
      {
         this.executeCallBack();
      }
   }
};
FSelectableListClass.prototype.setDataProvider = function(obj)
{
   this.setScrollPosition(0);
   this.clearSelected();
   if(obj instanceof Array)
   {
      this.dataProvider = new DataProviderClass();
      var i = 0;
      while(i < obj.length)
      {
         var value = typeof obj[i] != "string" ? obj[i] : {label:obj[i]};
         this.dataProvider.addItem(value);
         i++;
      }
   }
   else
   {
      this.dataProvider = obj;
   }
   this.dataProvider.addView(this);
};
FSelectableListClass.prototype.setItemSymbol = function(linkID)
{
   this.tmpPos = this.getScrollPosition();
   this.itemSymbol = linkID;
   this.invalidate("setSize");
   this.setScrollPosition(this.tmpPos);
};
FSelectableListClass.prototype.setEnabled = function(enabledFlag)
{
   this.cleanUI();
   super.setEnabled(enabledFlag);
   this.enable = enabledFlag;
   this.boundingBox_mc.gotoAndStop(!this.enable ? "disabled" : "enabled");
   var limit = Math.min(this.numDisplayed,this.getLength());
   var i = 0;
   while(i < limit)
   {
      this.container_mc["fListItem" + i + "_mc"].setEnabled(this.enable);
      i++;
   }
   if(this.enable)
   {
      this.invalidate("updateControl");
   }
};
FSelectableListClass.prototype.updateControl = function()
{
   var i = 0;
   while(i < this.numDisplayed)
   {
      this.container_mc["fListItem" + i + "_mc"].drawItem(this.getItemAt(this.topDisplayed + i),this.isSelected(this.topDisplayed + i));
      i++;
   }
};
FSelectableListClass.prototype.setSize = function(w, h)
{
   super.setSize(w,h);
   this.boundingBox_mc._xscale = this.boundingBox_mc._yscale = 100;
   this.boundingBox_mc._xscale = this.width * 100 / this.boundingBox_mc._width;
   this.boundingBox_mc._yscale = this.height * 100 / this.boundingBox_mc._height;
   var i = 0;
   while(i < this.numDisplayed)
   {
      this.container_mc.attachMovie(this.itemSymbol,"fListItem" + i + "_mc",10 + i,{controller:this,itemNum:i});
      var item_mc = this.container_mc["fListItem" + i + "_mc"];
      var offset = this.scrollOffset != undefined ? this.scrollOffset : 0;
      item_mc.setSize(this.width - offset,this.itmHgt);
      item_mc._y = (this.itmHgt - 2) * i;
      i++;
   }
   this.updateControl();
};
FSelectableListClass.prototype.modelChanged = function(eventObj)
{
   var firstRow = eventObj.firstRow;
   var lastRow = eventObj.lastRow;
   var event = eventObj.event;
   if(event == "addRows")
   {
      for(var i in this.selected)
      {
         if(this.selected[i].sIndex != undefined && this.selected[i].sIndex >= firstRow)
         {
            this.selected[i].sIndex += lastRow - firstRow + 1;
            this.setSelectedIndex(this.selected[i].sIndex,false);
         }
      }
   }
   else if(event == "deleteRows")
   {
      if(firstRow == lastRow)
      {
         var index = firstRow;
         if(this.selectHolder == index)
         {
            this.selectionDeleted = true;
         }
         if(this.topDisplayed + this.numDisplayed >= this.getLength() && this.topDisplayed > 0)
         {
            this.topDisplayed--;
            if(this.selectionDeleted && index - 1 >= 0)
            {
               this.setSelectedIndex(index - 1,false);
            }
         }
         else if(this.selectionDeleted)
         {
            var len = this.getLength();
            if(index == len - 1 && len > 1 || index > len / 2)
            {
               this.setSelectedIndex(index - 1,false);
            }
            else
            {
               this.setSelectedIndex(index,false);
            }
         }
         for(var i in this.selected)
         {
            if(this.selected[i].sIndex > firstRow)
            {
               this.selected[i].sIndex--;
            }
         }
      }
      else
      {
         this.clearSelected();
         this.topDisplayed = 0;
      }
   }
   else if(event == "sort")
   {
      var len = this.getLength();
      var i = 0;
      while(i < len)
      {
         if(this.isSelected(i))
         {
            var id = this.dataProvider.getItemID(i);
            if(id == this.lastSelID)
            {
               this.lastSelected = i;
            }
            this.selected[String(id)].sIndex = i;
         }
         i++;
      }
   }
   this.invalidate("updateControl");
};
FSelectableListClass.prototype.measureItmHgt = function()
{
   this.attachMovie(this.itemSymbol,"tmpItem_mc",0,{controller:this});
   this.tmpItem_mc.drawItem({label:"Sizer: PjtTopg"},false);
   this.itmHgt = this.tmpItem_mc._height;
   this.tmpItem_mc.removeMovieClip();
};
FSelectableListClass.prototype.selectItem = function(index, selectedFlag)
{
   if(selectedFlag && !this.isSelected(index))
   {
      this.selected[String(this.dataProvider.getItemID(index))] = {sIndex:index};
   }
   else if(!selectedFlag)
   {
      delete this.selected[String(this.dataProvider.getItemID(index))];
   }
};
FSelectableListClass.prototype.isSelected = function(index)
{
   return this.selected[String(this.dataProvider.getItemID(index))].sIndex != undefined;
};
FSelectableListClass.prototype.clearSelected = function()
{
   for(var uniqueID in this.selected)
   {
      var index = this.selected[uniqueID].sIndex;
      if(index != undefined && this.topDisplayed <= index && index < this.topDisplayed + this.numDisplayed)
      {
         this.container_mc["fListItem" + (index - this.topDisplayed) + "_mc"].drawItem(this.getItemAt(index),false);
      }
   }
   delete this.selected;
   this.selected = new Array();
};
FSelectableListClass.prototype.selectionHandler = function(itemNum)
{
   var tmpInd = this.topDisplayed + itemNum;
   if(this.getItemAt(tmpInd == undefined))
   {
      this.changeFlag = false;
      return undefined;
   }
   this.changeFlag = true;
   this.clearSelected();
   this.selectItem(tmpInd,true);
   this.container_mc["fListItem" + itemNum + "_mc"].drawItem(this.getItemAt(tmpInd),this.isSelected(tmpInd));
};
FSelectableListClass.prototype.moveSelBy = function(incr)
{
   var itmNum = this.getSelectedIndex();
   var newItm = itmNum + incr;
   newItm = Math.max(0,newItm);
   newItm = Math.min(this.getLength() - 1,newItm);
   if(newItm == itmNum)
   {
      return undefined;
   }
   if(itmNum < this.topDisplayed || itmNum >= this.topDisplayed + this.numDisplayed)
   {
      this.setScrollPosition(itmNum);
   }
   if(newItm >= this.topDisplayed + this.numDisplayed || newItm < this.topDisplayed)
   {
      this.setScrollPosition(this.topDisplayed + incr);
   }
   this.selectionHandler(newItm - this.topDisplayed);
};
FSelectableListClass.prototype.clickHandler = function(itmNum)
{
   this.focusRect.removeMovieClip();
   if(!this.focused)
   {
      this.pressFocus();
   }
   this.selectionHandler(itmNum);
   this.onMouseUp = this.releaseHandler;
};
FSelectableListClass.prototype.releaseHandler = function()
{
   if(this.changeFlag)
   {
      this.executeCallBack();
   }
   this.changeFlag = false;
   this.onMouseUp = undefined;
};
FSelectableListClass.prototype.myOnSetFocus = function()
{
   super.myOnSetFocus();
   var i = 0;
   while(i < this.numDisplayed)
   {
      this.container_mc["fListItem" + i + "_mc"].highlight_mc.gotoAndStop("enabled");
      i++;
   }
};
FSelectableListClass.prototype.myOnKillFocus = function()
{
   super.myOnKillFocus();
   var i = 0;
   while(i < this.numDisplayed)
   {
      this.container_mc["fListItem" + i + "_mc"].highlight_mc.gotoAndStop("unfocused");
      i++;
   }
};
