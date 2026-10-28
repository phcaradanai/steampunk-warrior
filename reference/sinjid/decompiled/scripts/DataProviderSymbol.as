_global.DataProviderClass = function()
{
   this.init();
};
DataProviderClass.prototype.init = function()
{
   this.items = new Array();
   this.uniqueID = 0;
   this.views = new Array();
};
DataProviderClass.prototype.addView = function(viewRef)
{
   this.views.push(viewRef);
   var eventObj = {event:"updateAll"};
   viewRef.modelChanged(eventObj);
};
DataProviderClass.prototype.addItemAt = function(index, value)
{
   if(index < this.getLength())
   {
      this.items.splice(index,0,"tmp");
   }
   this.items[index] = new Object();
   if(typeof value == "object")
   {
      this.items[index] = value;
   }
   else
   {
      this.items[index].label = value;
   }
   this.items[index].__ID__ = this.uniqueID++;
   var eventObj = {event:"addRows",firstRow:index,lastRow:index};
   this.updateViews(eventObj);
};
DataProviderClass.prototype.addItem = function(value)
{
   this.addItemAt(this.getLength(),value);
};
DataProviderClass.prototype.removeItemAt = function(index)
{
   var tmpItm = this.items[index];
   this.items.splice(index,1);
   var eventObj = {event:"deleteRows",firstRow:index,lastRow:index};
   this.updateViews(eventObj);
   return tmpItm;
};
DataProviderClass.prototype.removeAll = function()
{
   this.items = new Array();
   this.updateViews({event:"deleteRows",firstRow:0,lastRow:this.getLength() - 1});
};
DataProviderClass.prototype.replaceItemAt = function(index, itemObj)
{
   if(index < 0 || index >= this.getLength())
   {
      return undefined;
   }
   var tmpID = this.getItemID(index);
   if(typeof itemObj == "object")
   {
      this.items[index] = itemObj;
   }
   else
   {
      this.items[index].label = itemObj;
   }
   this.items[index].__ID__ = tmpID;
   this.updateViews({event:"updateRows",firstRow:index,lastRow:index});
};
DataProviderClass.prototype.getLength = function()
{
   return this.items.length;
};
DataProviderClass.prototype.getItemAt = function(index)
{
   return this.items[index];
};
DataProviderClass.prototype.getItemID = function(index)
{
   return this.items[index].__ID__;
};
DataProviderClass.prototype.sortItemsBy = function(fieldName, order)
{
   this.items.sortOn(fieldName);
   if(order == "DESC")
   {
      this.items.reverse();
   }
   this.updateViews({event:"sort"});
};
DataProviderClass.prototype.updateViews = function(eventObj)
{
   var i = 0;
   while(i < this.views.length)
   {
      this.views[i].modelChanged(eventObj);
      i++;
   }
};
