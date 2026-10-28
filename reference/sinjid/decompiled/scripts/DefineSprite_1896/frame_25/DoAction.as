if(_root[_root.herotarget + "life"] > 0)
{
   _root[dmgtype + "Damage"](0,_root[mcname + "magdmg"] + 15 + _root.skill[1] * 7 + _root.skill[8] * 7,false,0,0,_root[mcname + "speed"],random(_root[mcname + "phydmg"] / 3) + random(5));
}
