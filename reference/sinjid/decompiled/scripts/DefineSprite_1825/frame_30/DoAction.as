if(subject == "hero1")
{
   _root[dmgtype + "Damage"](_root[mcname + "phydmg"] + _root.skill[10] * 5,_root[mcname + "magdmg"],false,_root[mcname + "shddmg"],_root[mcname + "str"],_root[mcname + "speed"],random(_root[mcname + "phydmg"] / 3));
}
else
{
   _root[dmgtype + "Damage"](_root[mcname + "phydmg"],_root[mcname + "magdmg"],false,_root[mcname + "shddmg"],_root[mcname + "str"],_root[mcname + "speed"],random(_root[mcname + "phydmg"] / 3));
}
