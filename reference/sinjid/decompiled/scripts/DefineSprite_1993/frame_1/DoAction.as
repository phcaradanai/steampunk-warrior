_root.endtrain = false;
_root.midfight = true;
_root.bg.gotoAndStop(_root.bgstage);
_root.hero1bodyparts = new Array();
_root.hero1bodyparts = ["body","arm1","arm2","handarm1","handarm2","leg1","leg2","feetleg1","feetleg2","feet1","feet2"];
_root.hero1suit = _root.Suit;
_root.hero1helmet = _root.Helmet;
_root.hero1swordtype = _root.Weapon;
_root.hero1shieldtype = _root.Shield;
_root.hero1speed = _root.speedb + _root.skill[7] * 2;
_root.hero1str = _root.strb;
_root.hero1manamax = _root.manamaxb;
_root.hero1mana = _root.manab;
_root.hero1lifemax = _root.lifemaxb;
_root.hero1life = _root.lifeb;
_root.hero1bar._width = _root.hero1life / _root.hero1lifemax * _root.hero1bar.widthkeep;
_root.hero1shddmg = _root.shddmgb;
_root.hero1phydmg = _root.phydmgb;
_root.hero1magdmg = _root.magdmgb;
if(_root.shdptsb == 0)
{
   _root.hero1shdptsmax = 1;
}
else
{
   _root.hero1shdptsmax = _root.shdptsb;
}
_root.hero1shdpts = _root.shdptsb;
_root.hero1phydef = _root.phydefb;
_root.hero1magdef = _root.magdefb;
_root.hero1shdmagdef = _root.shdphydefb;
_root.hero1shdphydef = _root.shdmagdefb;
