_global.FLabelClass = function()
{
   if(this.hostComponent == undefined)
   {
      this.hostComponent = this._parent.controller != undefined ? this._parent.controller : this._parent;
   }
   if(this.customTextStyle == undefined)
   {
      if(this.hostComponent.textStyle == undefined)
      {
         this.hostComponent.textStyle = new TextFormat();
      }
      this.textStyle = this.hostComponent.textStyle;
      this.enable = true;
   }
};
FLabelClass.prototype = new MovieClip();
Object.registerClass("FLabelSymbol",FLabelClass);
FLabelClass.prototype.setLabel = function(label)
{
   var val = this.hostComponent.styleTable.embedFonts.value;
   if(val != undefined)
   {
      this.labelField.embedFonts = val;
   }
   this.labelField.setNewTextFormat(this.textStyle);
   this.labelField.text = label;
   this.labelField._height = this.labelField.textHeight + 2;
};
FLabelClass.prototype.setSize = function(width)
{
   this.labelField._width = width;
};
FLabelClass.prototype.setEnabled = function(enable)
{
   this.enable = enable;
   var tmpColor = this.hostComponent.styleTable[!enable ? "textDisabled" : "textColor"].value;
   if(tmpColor == undefined)
   {
      tmpColor = !enable ? 8947848 : 0;
   }
   this.setColor(tmpColor);
};
FLabelClass.prototype.getLabel = function()
{
   return this.labelField.text;
};
FLabelClass.prototype.setColor = function(col)
{
   this.labelField.textColor = col;
};
