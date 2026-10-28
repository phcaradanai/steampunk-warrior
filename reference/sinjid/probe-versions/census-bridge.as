// Analyst-only bridge appended to one DoAction in a separate SWF6 copy.
// No combat, item, scene or skill implementation is replaced.
_root.reaLastSeq = "-1";
_root.reaPending = 0;
function reaEmit() {
   var keys = ["reaSeq","reaMode","level","lifeb","manab","engb","gold","rests","currentstage","hero1life","hero1lifemax","hero1mana","hero1speed","hero1phydmg","hero1magdmg","hero1shdpts","hero1phydef","hero1magdef","hero2life","hero2speed","enemy1life","enemy2life","enemy1speed","enemy2speed","enemy1suit","enemy2suit","enemy1shdpts","enemy2shdpts","playermove","turnnum","midfight","herotarget","enemytarget","endtrain","exprate","engrate","expb","expmaxb","skillpts","moon_q"];
   var output = "frame=" + _root._currentframe;
   for (var ri = 0; ri < keys.length; ri++) {
      output += "&" + keys[ri] + "=" + escape(String(_root[keys[ri]]));
   }
   output += "&reaResult=" + escape(String(_root.reaResult));
   output += "&skill=" + escape(String(_root.skill)) + "&itemstats=" + escape(String(_root.itemstats));
   output += "&undefinedPlusOne=" + escape(String(undefined + 1));
   output += "&charx=" + _root.grid.char._x + "&chary=" + _root.grid.char._y;
   fscommand("rea", output);
}
function reaPoll() {
   _root.loadVariables("http://127.0.0.1:8765/runtime/probe.txt?t=" + getTimer());
   if (_root.reaSeq != undefined && String(_root.reaSeq) != String(_root.reaLastSeq)) {
      _root.reaLastSeq = String(_root.reaSeq);
      if (_root.reaMode == "jump") {
         _root.bgstage = "Snow";
         _root.gotoAndStop(_root.reaTarget);
      }
      if (_root.reaMode == "prepare") {
         // Controlled test fixture; never represent these as natural player stats.
         _root.lifemaxb = 50000;
         _root.lifeb = 50000;
         _root.manamaxb = 50000;
         _root.manab = 50000;
         _root.engmaxb = 50000;
         _root.engb = 50000;
         _root.level = 30;
         _root.strb = 20;
         _root.speedb = 20;
         _root.phydmgb = 10;
         _root.magdmgb = 10;
         _root.phydefb = 0;
         _root.magdefb = 0;
         _root.shdptsb = 0;
         _root.portallevel = [21,11,6];
         for (var sk = 0; sk < 19; sk++) { _root.skill[sk] = 10; }
      }
      if (_root.reaMode == "set") {
         var allowed = ["hero1life","hero1mana","hero1speed","enemy1life","enemy2life","turnnum","midfight","hero1shdpts","hero1phydef","hero1magdef","herotarget","enemytarget","lifeb","manab","engb"];
         for (var si = 0; si < allowed.length; si++) {
            if (allowed[si] == _root.reaName) {
               _root[allowed[si]] = Number(_root.reaValue);
            }
         }
      }
      if (_root.reaMode == "position") {
         _root.game.char.x = Number(_root.reaX);
         _root.game.char.y = Number(_root.reaY);
         _root.game.char.clip._x = Number(_root.reaX);
         _root.game.char.clip._y = Number(_root.reaY);
         _root.charything = Number(_root.reaY);
      }
      if (_root.reaMode == "inventory") {
         _root.pause = true;
         _root.inventory._visible = true;
         _root.inventory.gotoAndStop(_root.reaTarget);
      }
      if (_root.reaMode == "item") {
         _root.itemstats[4] = _root.reaTarget;
         _root.pause = false;
         _root.talking = false;
         _root.clearstage = false;
         _root.inventory._visible = false;
      }
      if (_root.reaMode == "arithmetic") {
         _root.midfight = true;
         _root.enemytarget = "hero1";
         _root.hero1speed = 0;
         _root.hero1shdpts = 0;
         _root.hero1phydef = 0;
         _root.hero1magdef = 0;
         _root.hero1life = 100;
         _root.enemyDamage(0,20,true,0,0,20);
         var omitted = 100 - _root.hero1life;
         _root.hero1life = 100;
         _root.hero1phydef = 25;
         _root.hero1magdef = 75;
         _root.enemyDamage(0,20,true,0,0,20,0);
         var physical = 100 - _root.hero1life;
         _root.hero1life = 100;
         _root.enemyDamage(40,0,true,0,0,20,0);
         var magical = 100 - _root.hero1life;
         _root.hero1life = 100;
         _root.hero1shdpts = 5;
         _root.hero1shdphydef = 0;
         _root.hero1shdmagdef = 0;
         _root.enemyDamage(0,20,true,0,0,20,0);
         _root.reaResult = "omitted:" + omitted + ",physical:" + physical + ",magical:" + magical + ",shield:" + _root.hero1shdpts + ",life:" + _root.hero1life;
      }
      if (_root.reaMode == "tie") {
         _root.midfight = true;
         _root.hero1speed = 20;
         _root.hero2speed = 20;
         _root.enemy1speed = 20;
         _root.enemy2speed = 20;
         _root.speedorder();
         _root.reaResult = String(_root.playermove);
      }
      if (_root.reaMode == "skillFixture") {
         // Put the original battle UI into a deterministic selectable test turn.
         _root.hero1lifemax = 50000;
         _root.hero1life = 25000;
         _root.hero1manamax = 50000;
         _root.hero1mana = 1000;
         _root.hero1speed = 20;
         _root.hero1shdpts = 0;
         _root.hero2life = 0;
         _root.enemy1life = 50000;
         _root.enemy2life = 50000;
         _root.enemy1shdpts = 0;
         _root.enemy2shdpts = 0;
         _root.playermove = ["hero1","enemy1","enemy2","hero2"];
         _root.turnnum = 0;
         _root.midfight = false;
         _root.herotarget = "enemy1";
      }
      _root.reaPending = 2;
   }
   else if (_root.reaPending > 0) {
      reaEmit();
      _root.reaPending--;
   }
}
_root.reaTimer = setInterval(reaPoll, 350);
trace("REA bridge ready; controlled instrumented copy");
