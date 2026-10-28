onClipEvent(enterFrame){
   setProperty(_this, _width, 112.2 * (_root.getBytesLoaded() / _root.getBytesTotal()));
}
