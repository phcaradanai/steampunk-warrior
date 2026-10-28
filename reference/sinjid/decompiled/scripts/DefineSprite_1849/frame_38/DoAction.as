if(_root[_root.herotarget + "life"] > 0)
{
   _root[dmgtype + "Damage"](_root[mcname + "phydmg"] / 100 * (60 + 5 * _root.skill[17]) + _root.skill[10] * 5,_root[mcname + "magdmg"],false,_root[mcname + "shddmg"],_root[mcname + "str"],_root[mcname + "speed"],random(_root[mcname + "phydmg"] / 3) + random(10));
}
