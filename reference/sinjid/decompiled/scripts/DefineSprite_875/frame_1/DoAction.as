head.gotoAndStop(_root.Helmet);
for(i in _root.BodyParts)
{
   tellTarget(_root.BodyParts[i])
   {
      gotoAndStop(_root.Suit);
   }
}
