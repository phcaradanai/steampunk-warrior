_root.savetarget = _root.herotarget;
if(_root.enemy1life > 0)
{
   _root.herotarget = "enemy1";
   _root[dmgtype + "Damage"](0,_root[mcname + "magdmg"] + (15 + _root.skill[1] * 7) + _root.skill[8] * 7,false,0,0,_root[mcname + "speed"],random(_root[mcname + "phydmg"] / 3) + random(5));
}
if(_root.enemy2life > 0)
{
   _root.herotarget = "enemy2";
   _root[dmgtype + "Damage"](0,_root[mcname + "magdmg"] + (15 + _root.skill[1] * 7) + _root.skill[8] * 7,false,_root[mcname + "shddmg"],_root[mcname + "str"],_root[mcname + "speed"],random(_root[mcname + "phydmg"] / 3) + random(5));
}
_root.herotarget = _root.savetarget;
