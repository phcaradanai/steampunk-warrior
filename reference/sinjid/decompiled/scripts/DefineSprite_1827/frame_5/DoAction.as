_root[subject + "shieldtype"] = "None";
sword.gotoAndStop(_root[subject + "swordtype"]);
head.gotoAndStop(_root[subject + "Helmet"]);
shield.gotoAndStop(_root[subject + "shieldtype"]);
for(i in _root[subject + "BodyParts"])
{
   tellTarget(_root[subject + "BodyParts"][i])
   {
      gotoAndStop(_root[_parent.subject + "Suit"]);
   }
}
