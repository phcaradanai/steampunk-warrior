function gameClicked(mx, my)
{
   if(tilelock == false)
   {
      var x = Math.ceil(mx / game.spacing);
      var y = Math.ceil(my / game.spacing);
      var cell = "cell" + x + "_" + y;
      var ob = game[cell];
      trace("game." + (cell = "cell" + x + "_" + y) + ".type = 2");
      if(ob.type < game.numberOfTypes)
      {
         ob.type++;
      }
      else
      {
         ob.type = 1;
      }
      ob.clip.tile.gotoAndStop(ob.type);
   }
}
function movechar(dir)
{
   ob = game.char;
   if(dir == "right")
   {
      var tempx = ob.x + ob.radius + game.speed;
      var tempy = ob.y;
      var cellx = Math.ceil(tempx / game.spacing);
      var celly = Math.ceil(tempy / game.spacing);
      var tempCell = game["cell" + cellx + "_" + celly];
      if(tempCell.type != 1)
      {
         return undefined;
      }
      ob.x += game.speed;
      ob.clip._x = ob.x;
   }
   else if(dir == "left")
   {
      var tempx = ob.x - ob.radius - game.speed;
      var tempy = ob.y;
      var cellx = Math.ceil(tempx / game.spacing);
      var celly = Math.ceil(tempy / game.spacing);
      var tempCell = game["cell" + cellx + "_" + celly];
      if(tempCell.type != 1)
      {
         return undefined;
      }
      ob.x -= game.speed;
      ob.clip._x = ob.x;
   }
   else if(dir == "up")
   {
      var tempx = ob.x;
      var tempy = ob.y - ob.radius - game.speed;
      var cellx = Math.ceil(tempx / game.spacing);
      var celly = Math.ceil(tempy / game.spacing);
      var tempCell = game["cell" + cellx + "_" + celly];
      if(tempCell.type != 1)
      {
         return undefined;
      }
      ob.y -= game.speed;
      ob.clip._y = ob.y;
      charything = ob.y;
   }
   else if(dir == "down")
   {
      var tempx = ob.x;
      var tempy = ob.y + ob.radius + game.speed;
      var cellx = Math.ceil(tempx / game.spacing);
      var celly = Math.ceil(tempy / game.spacing);
      var tempCell = game["cell" + cellx + "_" + celly];
      if(tempCell.type != 1)
      {
         return undefined;
      }
      ob.y += game.speed;
      ob.clip._y = ob.y;
      charything = ob.y;
   }
}
function initializeChar(start_x, start_y)
{
   game.speed = 5.25;
   game.path.char.swapDepths(10200);
   game.char = {startx:start_x,starty:start_y,clip:game.path.char};
   var x = (game.char.startx - 1) * game.spacing + game.spacing / 2;
   var y = (game.char.starty - 1) * game.spacing + game.spacing / 2;
   game.char.clip._x = x;
   game.char.clip._y = y;
   game.char.x = x;
   game.char.y = y;
   game.char.radius = game.char.clip._width / 3;
}
function buildGrid()
{
   var j = 1;
   while(j <= game.rows)
   {
      var i = 1;
      while(i <= game.columns)
      {
         var name = "cell" + i + "_" + j;
         var x = (i - 1) * game.spacing;
         var y = (j - 1) * game.spacing;
         var type = 1;
         game.path.attachMovie("cell",name,++game.depth);
         game.path[name]._x = x;
         game.path[name]._y = y;
         game[name] = {x:i,y:j,name:name,type:type,clip:game.path[name]};
         i++;
      }
      j++;
   }
}
game = {};
game.columns = 20;
game.rows = 11;
game.spacing = 30;
game.depth = 1020;
game.path = _root.grid;
game.numberOfTypes = 2;
_root.onEnterFrame = function()
{
   if(pause == false)
   {
      if(_root.engb > 0)
      {
         game.speed = 6;
      }
      else
      {
         game.speed = 4;
      }
      if(Key.isDown(39) || Key.isDown(68))
      {
         movechar("right");
      }
      else if(Key.isDown(37) || Key.isDown(65))
      {
         movechar("left");
      }
      if(Key.isDown(38) || Key.isDown(87))
      {
         movechar("up");
      }
      else if(Key.isDown(40) || Key.isDown(83))
      {
         movechar("down");
      }
   }
};
_root.onMouseDown = function()
{
   if(Key.isDown(16))
   {
      var mx = _xmouse;
      var my = _ymouse;
      if(game.path.hitTest(mx,my))
      {
         gameClicked(game.path._xmouse,game.path._ymouse);
      }
   }
};
buildGrid();
initializeChar(10.5,7);
charything = game.char.clip._y;
