stop();
droppedstuff = "None";
Balanced = [10,10,2,2,"Balanced"];
Warrior = [15,5,3,1,"Warrior"];
Spellcaster = [10,15,1,2,"Spell Caster"];
Shadow = [10,10,1,3,"Shadow Ninja"];
prevsound = 0;
_root.playername = "Sinjid";
user = SharedObject.getLocal("user_profile");
portal2 = new Array();
portal1 = new Array();
portal3 = new Array();
rests = 10;
i = 1;
while(i < 21)
{
   portal1[i] = "HUMAN" + i;
   i++;
}
i = 1;
while(i < 21)
{
   portal2[i] = "MONSTER" + i;
   i++;
}
i = 1;
while(i < 21)
{
   portal3[i] = "DARK" + i;
   i++;
}
portalstages = ["Snow","Coast","Grass","Desert"];
portallevel = new Array();
portallevel = [0,0,0];
i = 0;
while(i < 3)
{
   _root.portallevel[i] = 1;
   i++;
}
pause = false;
itemlog = new Array();
i = 0;
while(i < 30)
{
   _root.itemlog[i] = false;
   i++;
}
_root.skill = new Array();
i = 0;
while(i < 20)
{
   _root.skill[i] = 0;
   i++;
}
BodyParts = new Array();
BodyParts = ["body","arm1","arm2","handarm1","handarm2","leg1","leg2","feetleg1","feetleg2","feet1","feet2"];
_root.itemstats = new Array();
i = 0;
while(i < 28)
{
   _root.itemstats[i] = "None";
   i++;
}
area = "Arena";
Helmet = "None";
Suit = "None";
Weapon = "Iron Knife";
level = 1;
gold = 75;
Shield = "None";
statpts = 0;
lifepots = 5;
manapots = 5;
manamaxb = 75;
manab = 75;
speedb = 15;
strb = 15;
lifemaxb = 75;
lifeb = 75;
engmaxb = 50;
engb = engmaxb;
expmaxb = 50;
expb = 0;
phydmgb = 0;
magdmgb = 0;
phydefb = 0;
magdefb = 0;
shddmgb = 0;
shdphydefb = 0;
shdmagdefb = 0;
shdptsb = 0;
skillpts = 0;
moon_q = false;
_root.phydmgb += _root.item["iron Knife"][2];
_root.itempick = "None";
_root.itemstats[0] = "Iron Knife";
