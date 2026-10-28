function Heal(healpoints, whotoheal, healtype)
{
   _root[whotoheal + healtype] += healpoints;
   if(_root[whotoheal + healtype] > _root[whotoheal + healtype + "max"])
   {
      _root[whotoheal + healtype] = _root[whotoheal + healtype + "max"];
   }
   _root[whotoheal + "counter"].dmg = healpoints;
   _root[whotoheal + "counter"].gotoAndPlay(healtype);
}
function SearchNone()
{
   i = 4;
   while(i < 12)
   {
      if(_root.itemstats[[i]] == "None" && _root.Searched != true)
      {
         _root.Searched = true;
      }
      i++;
   }
}
function SearchItem(item, ask)
{
   i = 0;
   while(i < 12)
   {
      if(_root.itemstats[[i]] == item && _root.Searched != true)
      {
         _root.Searched = true;
         if(ask = true)
         {
            _root.itemstats[[i]] = "None";
         }
      }
      i++;
   }
}
function ItemRand(k0, k1, k2)
{
   ia = new Array();
   if(k0 != "")
   {
      ia.push(k0);
   }
   if(k1 != "")
   {
      ia.push(k1);
   }
   if(k2 != "")
   {
      ia.push(k2);
   }
   rand = random(ia.length);
   droppedstuff = ia[rand];
   trace(droppedstuff);
}
function GetItemDrop(item)
{
   didget = false;
   i = 4;
   while(i < 12)
   {
      if(_root.itemstats[[i]] == "None" && didget == false)
      {
         itemsign._visible = true;
         _root.itemstats[[i]] = item;
         didget = true;
      }
      i++;
   }
}
function GetItem(item, cost)
{
   if(_root.gold >= cost)
   {
      didget = false;
      i = 4;
      while(i < 12)
      {
         if(_root.itemstats[[i]] == "None" && didget == false)
         {
            _root.itemstats[[i]] = item;
            _root.playSound("itemget");
            _root.gold -= cost;
            _root.got = true;
            didget = true;
         }
         else if(i == 11)
         {
            _root.playSound("no");
         }
         i++;
      }
   }
}
function ExplainItem()
{
   _root.itemarray = ["","","Physical Damage","Magic/Elemental Damage","Extra Shield Damage","Physical Defence","Magic/Elemental Defence","Shield Phys. Defence","Shield Magic/Elem. Defence","Shield Hit Points","Speed","Bonus Life","Bonus Mana","Specail Skill"];
   i = 0;
   while(i < 4)
   {
      _root.inventory.explainbox["statname" + i] = "";
      _root.inventory.explainbox["stat" + i] = "";
      i++;
   }
   if(_root.itempick == "None" && _root.itemstats[_root.slotnum] != "None")
   {
      if(_root.item[_root.itemstats[_root.slotnum]][1] == "Food" || _root.item[_root.itemstats[_root.slotnum]][1] == "Drink")
      {
         _root.itemarray[2] = "Energy Points";
         _root.itemarray[3] = "Life Points";
         _root.itemarray[4] = "Mana Points";
      }
      _root.inventory.explainbox.name = _root.item[_root.itemstats[_root.slotnum]][0];
      _root.inventory.explainbox.itemtype = _root.item[_root.itemstats[_root.slotnum]][1];
      _root.inventory.explainbox.strneed = _root.item[_root.itemstats[_root.slotnum]][14];
      _root.inventory.explainbox.explain = _root.item[_root.itemstats[_root.slotnum]][15];
      itmnum = 0;
      i = 2;
      while(i < 14)
      {
         if(_root.item[_root.itemstats[_root.slotnum]][i] != 0 && itmnum < 4)
         {
            _root.inventory.explainbox["statname" + itmnum] = _root.itemarray[i];
            _root.inventory.explainbox["stat" + itmnum] = _root.item[_root.itemstats[_root.slotnum]][i];
            itmnum++;
         }
         i++;
      }
      _root.inventory.explainbox._visible = true;
   }
}
function AddItem(name, itmtyp, itmpdmg, itmmdmg, itmsdmg, itmpdef, itmmdef, itmspdef, itmsmdef, itmspts, itmspd, itmlif, itmstr, itmskl, strneed, itmx)
{
   _root.item[name] = new Array();
   statsputin = [name,itmtyp,itmpdmg,itmmdmg,itmsdmg,itmpdef,itmmdef,itmspdef,itmsmdef,itmspts,itmspd,itmlif,itmstr,itmskl,strneed,itmx];
   i = 0;
   while(i < 16)
   {
      _root.item[name][i] = statsputin[i];
      i++;
   }
}
function order(a, b)
{
   var name1 = a;
   var name2 = b;
   if(name1 < name2)
   {
      return -1;
   }
   if(name1 > name2)
   {
      return 1;
   }
}
function speedorder()
{
   _root.playermove = new Array();
   _root.turnnum = 0;
   spdturn = new Array();
   spdturn = [_root.hero1speed,_root.hero2speed,_root.enemy1speed,_root.enemy2speed];
   spdturn.sort(_root.order);
   spdturn.reverse();
   i = 0;
   while(i < 4)
   {
      j = 1;
      while(j < 3)
      {
         if(_root.spdturn[i] == _root["enemy" + [j] + "speed"] && _root.playermove[i - 1] != "enemy" + [j] && _root.playermove[i - 2] != "enemy" + [j] && _root.playermove[i - 3] != "enemy" + [j])
         {
            _root.playermove[i] = "enemy" + [j];
         }
         else if(_root.spdturn[i] == _root["hero" + [j] + "speed"] && _root.playermove[i - 1] != "hero" + [j] && _root.playermove[i - 2] != "hero" + [j] && _root.playermove[i - 3] != "hero" + [j])
         {
            _root.playermove[i] = "hero" + [j];
         }
         j++;
      }
      i++;
   }
}
function enemyDamage(magdmg, phydmg, nomiss, dmgtoshd, strdmg, atkspd, ran)
{
   spdran1 = random(atkspd / 2) + atkspd / 2;
   spdran2 = random(_root[_root.enemytarget + "speed"] / 2);
   if(nomiss == true)
   {
      spdran2 = -1;
   }
   if(spdran2 < spdran1)
   {
      if(_root[_root.enemytarget + "shdpts"] > 0)
      {
         shddmg = Math.round(phydmg - Math.ceil(phydmg / 100 * _root[_root.enemytarget + "shdphydef"]) + magdmg - Math.ceil(magdmg / 100 * _root[_root.enemytarget + "shdmagdef"]) + strdmg - Math.ceil(strdmg / 100 * _root[_root.enemytarget + "shdphydef"]) + dmgtoshd) + ran;
         _root[_root.enemytarget + "counter"].dmg = shddmg;
         _root[_root.enemytarget + "counter"].gotoAndPlay("blockdmg");
         if(_root[_root.enemytarget + "shdpts"] - shddmg <= 0)
         {
            _root[_root.enemytarget].gotoAndStop("blockbreak");
            _root[_root.enemytarget + "shdpts"] = 0;
         }
         else
         {
            _root[_root.enemytarget].gotoAndStop("block");
            _root[_root.enemytarget + "shdpts"] -= shddmg;
         }
      }
      else
      {
         totaldmg = Math.round(phydmg - Math.ceil(phydmg / 100 * _root[_root.enemytarget + "phydef"]) + magdmg - Math.ceil(magdmg / 100 * _root[_root.enemytarget + "magdef"]) + strdmg - Math.ceil(strdmg / 100 * _root[_root.enemytarget + "phydef"])) + ran;
         _root[_root.enemytarget + "counter"].dmg = totaldmg;
         _root[_root.enemytarget + "counter"].gotoAndPlay(2);
         _root[_root.enemytarget].gotoAndStop("hit");
         _root[_root.enemytarget + "life"] -= totaldmg;
         if(_root[_root.enemytarget + "life"] <= 0)
         {
            _root[_root.enemytarget].gotoAndStop("die");
            _root[_root.enemytarget + "life"] = 0;
         }
      }
   }
   else
   {
      _root[_root.enemytarget + "counter"].dmg = "miss";
      _root[_root.enemytarget + "counter"].gotoAndPlay(2);
      _root[_root.enemytarget].gotoAndStop("miss");
   }
}
function heroDamage(magdmg, phydmg, nomiss, dmgtoshd, strdmg, atkspd, ran)
{
   spdran1 = random(atkspd / 2) + atkspd / 2;
   spdran2 = random(_root[_root.herotarget + "speed"] / 2);
   if(nomiss == true)
   {
      spdran2 = -1;
   }
   if(spdran2 < spdran1)
   {
      if(_root[_root.herotarget + "shdpts"] > 0)
      {
         shddmg = Math.round(phydmg - Math.ceil(phydmg / 100 * _root[_root.herotarget + "shdphydef"]) + magdmg - Math.ceil(magdmg / 100 * _root[_root.herotarget + "shdmagdef"]) + strdmg - Math.ceil(strdmg / 100 * _root[_root.herotarget + "shdphydef"]) + dmgtoshd) + ran;
         _root[_root.herotarget + "counter"].dmg = shddmg;
         _root[_root.herotarget + "counter"].gotoAndPlay("blockdmg");
         if(_root[_root.herotarget + "shdpts"] - shddmg <= 0)
         {
            _root[_root.herotarget].gotoAndStop("blockbreak");
            _root[_root.herotarget + "shdpts"] = 0;
         }
         else
         {
            _root[_root.herotarget].gotoAndStop("block");
            _root[_root.herotarget + "shdpts"] -= shddmg;
         }
      }
      else
      {
         totaldmg = Math.round(phydmg - Math.ceil(phydmg / 100 * _root[_root.herotarget + "phydef"]) + magdmg - Math.ceil(magdmg / 100 * _root[_root.herotarget + "magdef"]) + strdmg - Math.ceil(strdmg / 100 * _root[_root.herotarget + "phydef"])) + ran;
         _root[_root.herotarget + "counter"].dmg = totaldmg;
         _root[_root.herotarget + "counter"].gotoAndPlay(2);
         _root[_root.herotarget].gotoAndStop("hit");
         _root[_root.herotarget + "life"] -= totaldmg;
         if(_root[_root.herotarget + "life"] <= 0)
         {
            _root[_root.herotarget].gotoAndStop("die");
            _root[_root.herotarget + "life"] = 0;
         }
      }
   }
   else
   {
      _root[_root.herotarget + "counter"].dmg = "miss";
      _root[_root.herotarget + "counter"].gotoAndPlay(2);
      _root[_root.herotarget].gotoAndStop("miss");
   }
}
function EnemyMeet()
{
   _root.save_stage = _root.currentstage;
   _root.save_x = _root.grid.char._x;
   _root.save_y = _root.grid.char._y;
   _root.clearstage = true;
   _root.clearscene = true;
}
function RemoveItem(label, need)
{
   _root[need] = "None";
   _root.phydmgb -= _root.item[label][2];
   _root.magdmgb -= _root.item[label][3];
   _root.shddmgb -= _root.item[label][4];
   _root.phydefb -= _root.item[label][5];
   _root.magdefb -= _root.item[label][6];
   _root.shdphydefb -= _root.item[label][7];
   _root.shdmagdefb -= _root.item[label][8];
   _root.shdptsb -= _root.item[label][9];
   _root.speedb -= _root.item[label][10];
   _root.lifemaxb -= _root.item[label][11];
   _root.manamaxb -= _root.item[label][12];
   _root.manab -= _root.item[label][12];
   if(_root.manab < 0)
   {
      _root.manab = 0;
   }
   _root.itemskill = "None";
}
function EquipItem(label, need)
{
   _root[need] = _root.item[label][0];
   _root.phydmgb += _root.item[label][2];
   _root.magdmgb += _root.item[label][3];
   _root.shddmgb += _root.item[label][4];
   _root.phydefb += _root.item[label][5];
   _root.magdefb += _root.item[label][6];
   _root.shdphydefb += _root.item[label][7];
   _root.shdmagdefb += _root.item[label][8];
   _root.shdptsb += _root.item[label][9];
   _root.speedb += _root.item[label][10];
   _root.lifemaxb += _root.item[label][11];
   _root.manamaxb += _root.item[label][12];
   _root.manab += _root.item[label][12];
   if(_root.manab > _root.manamaxb)
   {
      _root.manab = _root.manamaxb;
   }
   _root.itemskill = _root.item[label][13];
}
function NewStage(chardir, charposx, charposy)
{
   _root.grid.char.gotoAndStop(chardir);
   _root.grid.char._x = charposx * 30 - 15;
   _root.grid.char._y = charposy * 30 - 15;
   _root.game.char.x = charposx * 30 - 15;
   _root.game.char.y = charposy * 30 - 15;
   _root.charything = _root.grid.char._y;
   var j = 1;
   while(j <= game.rows)
   {
      var i = 1;
      while(i <= game.columns)
      {
         var name = "cell" + i + "_" + j;
         game[name].type = 1;
         i++;
      }
      j++;
   }
}
function Fight(move)
{
   _root[_root.playermove[_root.turnnum]].gotoAndStop(move);
}
_root.playSound("Dream");
_root.item = new Object();
