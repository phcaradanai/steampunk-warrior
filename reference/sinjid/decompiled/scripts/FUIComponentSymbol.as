function FUIComponentClass()
{
   this.init();
}
FUIComponentClass.prototype = new MovieClip();
FUIComponentClass.prototype.init = function()
{
   this.enable = true;
   this.focused = false;
   this.useHandCursor = false;
   this._accImpl = new Object();
   this._accImpl.stub = true;
   this.styleTable = new Array();
   if(_global.globalStyleFormat == undefined)
   {
      _global.globalStyleFormat = new FStyleFormat();
      globalStyleFormat.isGlobal = true;
      _global._focusControl = new Object();
      _global._focusControl.onSetFocus = function(oldFocus, newFocus)
      {
         oldFocus.myOnKillFocus();
         newFocus.myOnSetFocus();
      };
      Selection.addListener(_global._focusControl);
   }
   if(this._name != undefined)
   {
      this._focusrect = false;
      this.tabEnabled = true;
      this.focusEnabled = true;
      this.tabChildren = false;
      this.tabFocused = true;
      if(this.hostStyle == undefined)
      {
         globalStyleFormat.addListener(this);
      }
      else
      {
         this.styleTable = this.hostStyle;
      }
      this.deadPreview._visible = false;
      this.deadPreview._width = this.deadPreview._height = 1;
      this.methodTable = new Object();
      this.keyListener = new Object();
      this.keyListener.controller = this;
      this.keyListener.onKeyDown = function()
      {
         this.controller.myOnKeyDown();
      };
      this.keyListener.onKeyUp = function()
      {
         this.controller.myOnKeyUp();
      };
      for(var i in this.styleFormat_prm)
      {
         this.setStyleProperty(i,this.styleFormat_prm[i]);
      }
   }
};
FUIComponentClass.prototype.setEnabled = function(enabledFlag)
{
   this.enable = arguments.length <= 0 ? true : enabledFlag;
   this.tabEnabled = this.focusEnabled = enabledFlag;
   if(!this.enable && this.focused)
   {
      Selection.setFocus(undefined);
   }
};
FUIComponentClass.prototype.getEnabled = function()
{
   return this.enable;
};
FUIComponentClass.prototype.setSize = function(w, h)
{
   this.width = w;
   this.height = h;
   this.focusRect.removeMovieClip();
};
FUIComponentClass.prototype.setChangeHandler = function(chng, obj)
{
   this.handlerObj = obj != undefined ? obj : this._parent;
   this.changeHandler = chng;
};
FUIComponentClass.prototype.invalidate = function(methodName)
{
   this.methodTable[methodName] = true;
   this.onEnterFrame = this.cleanUI;
};
FUIComponentClass.prototype.cleanUI = function()
{
   if(this.methodTable.setSize)
   {
      this.setSize(this.width,this.height);
   }
   else
   {
      this.cleanUINotSize();
   }
   this.methodTable = new Object();
   delete this.onEnterFrame;
};
FUIComponentClass.prototype.cleanUINotSize = function()
{
   for(var funct in this.methodTable)
   {
      this[funct]();
   }
};
FUIComponentClass.prototype.drawRect = function(x, y, w, h)
{
   var inner = this.styleTable.focusRectInner.value;
   var outer = this.styleTable.focusRectOuter.value;
   if(inner == undefined)
   {
      inner = 16777215;
   }
   if(outer == undefined)
   {
      outer = 0;
   }
   this.createEmptyMovieClip("focusRect",1000);
   this.focusRect.controller = this;
   this.focusRect.lineStyle(1,outer);
   this.focusRect.moveTo(x,y);
   this.focusRect.lineTo(x + w,y);
   this.focusRect.lineTo(x + w,y + h);
   this.focusRect.lineTo(x,y + h);
   this.focusRect.lineTo(x,y);
   this.focusRect.lineStyle(1,inner);
   this.focusRect.moveTo(x + 1,y + 1);
   this.focusRect.lineTo(x + w - 1,y + 1);
   this.focusRect.lineTo(x + w - 1,y + h - 1);
   this.focusRect.lineTo(x + 1,y + h - 1);
   this.focusRect.lineTo(x + 1,y + 1);
};
FUIComponentClass.prototype.pressFocus = function()
{
   this.tabFocused = false;
   this.focusRect.removeMovieClip();
   Selection.setFocus(this);
};
FUIComponentClass.prototype.drawFocusRect = function()
{
   this.drawRect(-2,-2,this.width + 4,this.height + 4);
};
FUIComponentClass.prototype.myOnSetFocus = function()
{
   this.focused = true;
   Key.addListener(this.keyListener);
   if(this.tabFocused)
   {
      this.drawFocusRect();
   }
};
FUIComponentClass.prototype.myOnKillFocus = function()
{
   this.tabFocused = true;
   this.focused = false;
   this.focusRect.removeMovieClip();
   Key.removeListener(this.keyListener);
};
FUIComponentClass.prototype.executeCallBack = function()
{
   this.handlerObj[this.changeHandler](this);
};
FUIComponentClass.prototype.updateStyleProperty = function(styleFormat, propName)
{
   this.setStyleProperty(propName,styleFormat[propName],styleFormat.isGlobal);
};
FUIComponentClass.prototype.setStyleProperty = function(propName, value, isGlobal)
{
   if(value == "")
   {
      return undefined;
   }
   var tmpValue = parseInt(value);
   if(!isNaN(tmpValue))
   {
      value = tmpValue;
   }
   var global = arguments.length <= 2 ? false : isGlobal;
   if(this.styleTable[propName] == undefined)
   {
      this.styleTable[propName] = new Object();
      this.styleTable[propName].useGlobal = true;
   }
   if(this.styleTable[propName].useGlobal || !global)
   {
      this.styleTable[propName].value = value;
      if(!this.setCustomStyleProperty(propName,value))
      {
         if(propName == "embedFonts")
         {
            this.invalidate("setSize");
         }
         else if(propName.subString(0,4) == "text")
         {
            if(this.textStyle == undefined)
            {
               this.textStyle = new TextFormat();
            }
            var textProp = propName.subString(4,propName.length);
            this.textStyle[textProp] = value;
            this.invalidate("setSize");
         }
         else
         {
            for(var j in this.styleTable[propName].coloredMCs)
            {
               var myColor = new Color(this.styleTable[propName].coloredMCs[j]);
               if(this.styleTable[propName].value == undefined)
               {
                  var myTObj = {ra:"100",rb:"0",ga:"100",gb:"0",ba:"100",bb:"0",aa:"100",ab:"0"};
                  myColor.setTransform(myTObj);
               }
               else
               {
                  myColor.setRGB(value);
               }
            }
         }
      }
      this.styleTable[propName].useGlobal = global;
   }
};
FUIComponentClass.prototype.registerSkinElement = function(skinMCRef, propName)
{
   if(this.styleTable[propName] == undefined)
   {
      this.styleTable[propName] = new Object();
      this.styleTable[propName].useGlobal = true;
   }
   if(this.styleTable[propName].coloredMCs == undefined)
   {
      this.styleTable[propName].coloredMCs = new Object();
   }
   this.styleTable[propName].coloredMCs[skinMCRef] = skinMCRef;
   if(this.styleTable[propName].value != undefined)
   {
      var myColor = new Color(skinMCRef);
      myColor.setRGB(this.styleTable[propName].value);
   }
};
_global.FStyleFormat = function()
{
   this.nonStyles = {listeners:true,isGlobal:true,isAStyle:true,addListener:true,removeListener:true,nonStyles:true,applyChanges:true};
   this.listeners = new Object();
   this.isGlobal = false;
   if(arguments.length > 0)
   {
      for(var i in arguments[0])
      {
         this[i] = arguments[0][i];
      }
   }
};
_global.FStyleFormat.prototype = new Object();
FStyleFormat.prototype.addListener = function()
{
   var arg = 0;
   while(arg < arguments.length)
   {
      var mcRef = arguments[arg];
      this.listeners[arguments[arg]] = mcRef;
      for(var i in this)
      {
         if(this.isAStyle(i))
         {
            mcRef.updateStyleProperty(this,i.toString());
         }
      }
      arg++;
   }
};
FStyleFormat.prototype.removeListener = function(component)
{
   this.listeners[component] = undefined;
   for(var prop in this)
   {
      if(this.isAStyle(prop))
      {
         if(component.styleTable[prop].useGlobal == this.isGlobal)
         {
            component.styleTable[prop].useGlobal = true;
            var value = !this.isGlobal ? globalStyleFormat[prop] : undefined;
            component.setStyleProperty(prop,value,true);
         }
      }
   }
};
FStyleFormat.prototype.applyChanges = function()
{
   var count = 0;
   for(var i in this.listeners)
   {
      var component = this.listeners[i];
      if(arguments.length > 0)
      {
         var j = 0;
         while(j < arguments.length)
         {
            if(this.isAStyle(arguments[j]))
            {
               component.updateStyleProperty(this,arguments[j]);
            }
            j++;
         }
      }
      else
      {
         for(var j in this)
         {
            if(this.isAStyle(j))
            {
               component.updateStyleProperty(this,j.toString());
            }
         }
      }
   }
};
FStyleFormat.prototype.isAStyle = function(name)
{
   return !this.nonStyles[name] ? true : false;
};
