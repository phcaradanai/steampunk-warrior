if(subject == "hero1")
{
   _root.Heal(80,subject,"life");
}
else
{
   _root.Heal(4 * _root.portallevel[0],subject,"life");
}
