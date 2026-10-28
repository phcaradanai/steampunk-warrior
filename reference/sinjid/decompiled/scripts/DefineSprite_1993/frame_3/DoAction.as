setthing = ["hero1","hero2","enemy1","enemy2"];
for(i in setthing)
{
   _root[setthing[i] + "bar2"]._width = _root[setthing[i] + "shdpts"] / _root[setthing[i] + "shdptsmax"] * _root[setthing[i] + "bar2"].widthkeep;
}
