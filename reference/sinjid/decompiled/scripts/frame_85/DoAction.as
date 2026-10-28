itemsign._visible = false;
if(droppedstuff != "None")
{
   GetItemDrop(droppedstuff);
   droppedstuff = "None";
}
_root.conbut._visible = false;
stopAllSounds();
_root.playSound("Orc");
