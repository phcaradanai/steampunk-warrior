_root.hero2lifemax = 70 + 30 * _root.skill[18];
_root.hero2phydmg = 13 + 12 * _root.skill[18];
_root.hero2magdmg = 13 + 12 * _root.skill[18];
_root.hero2speed = _root.hero1speed + 4 * _root.skill[18];
_root.hero2life = _root.hero2lifemax;
_root.hero2bar._width = _root.hero2life / _root.hero2lifemax * _root.hero2bar.widthkeep;
