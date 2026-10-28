function FComboBoxItemClass()
{
   this.init();
}
FComboBoxItemClass.prototype = new FSelectableItemClass();
Object.registerClass("FComboBoxItemSymbol",FComboBoxItemClass);
FComboBoxItemClass.prototype.setSize = function(w, h)
{
   super.setSize(w,h);
   this.highlight_mc.onRollOver = function()
   {
      this.controller.controller.selectionHandler(this.controller.itemNum);
   };
};
