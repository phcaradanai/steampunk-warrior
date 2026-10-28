_root.savetarget = _root.herotarget;
if(_root.enemy1life > 0)
{
   _root.herotarget = "enemy1";
   _root[dmgtype + "Damage"](0,_root[mcname + "magdmg"] + 7 + 5 * _root.skill[5] + _root.skill[8] * 7,false,0,0,_root[mcname + "speed"] + 5,random(_root[mcname + "phydmg"] / 3) + random(5));
}
if(_root.enemy2life > 0)
{
   _root.herotarget = "enemy2";
   _root[dmgtype + "Damage"](0,_root[mcname + "magdmg"] + 7 + 5 * _root.skill[5] + _root.skill[8] * 7,false,0,0,_root[mcname + "speed"] + 5,random(_root[mcname + "phydmg"] / 3) + random(5));
}
_root.herotarget = _root.savetarget;
