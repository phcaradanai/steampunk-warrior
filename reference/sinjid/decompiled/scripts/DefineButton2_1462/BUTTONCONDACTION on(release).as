on(release){
   stopAllSounds();
   _root.clearstage = true;
   _root.cleargrid = true;
   removeMovieClip("TalkBox");
   removeMovieClip("inventory");
   removeMovieClip("objectives");
   removeMovieClip("blackout");
   gotoAndPlay(17);
}
