@echo off
color 0a
cd ..
@echo on
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
haxelib install lime
haxelib install openfl
haxelib install flixel
haxelib install flixel-addons
haxelib install flixel-tools
haxelib install tjson
haxelib install hxdiscord_rpc
haxelib install hxvlc --skip-dependencies
haxelib git hscript-iris https://github.com/pisayesiwsi/hscript-iris.git dev
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate dev.git
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis.git
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git
echo Finished!
pause
