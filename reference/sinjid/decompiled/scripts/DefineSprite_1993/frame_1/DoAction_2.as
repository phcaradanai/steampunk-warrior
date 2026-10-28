_root.hero2bodyparts = new Array();
_root.hero2bodyparts = ["body","arm1","arm2","handarm1","handarm2","leg1","leg2","feetleg1","feetleg2","feet1","feet2"];
_root.hero2suit = "Shadow";
_root.hero2helmet = _root.hero2suit;
_root.hero2swordtype = _root.hero2suit;
_root.hero2shieldtype = _root.hero2suit;
_root.hero2speed = _root.speedb;
_root.hero2str = _root.strb;
_root.hero2manamax = _root.manamaxb;
_root.hero2mana = _root.manab;
_root.hero2lifemax = 1;
_root.hero2life = 0;
_root.hero2bar._width = _root.hero2life / _root.hero2lifemax * _root.hero2bar.widthkeep;
_root.hero2shddmg = _root.shddmgb;
_root.hero2phydmg = _root.phydmgb;
_root.hero2magdmg = _root.magdmgb;
if(_root.shdptsb == 0)
{
   _root.hero2shdptsmax = 1;
}
else
{
   _root.hero2shdptsmax = _root.shdptsb;
}
_root.hero2shdpts = _root.shdptsb;
_root.hero2phydef = _root.phydefb;
_root.hero2magdef = _root.magdefb;
_root.hero2shdmagdef = _root.shdphydefb;
_root.hero2shdphydef = _root.shdmagdefb;
