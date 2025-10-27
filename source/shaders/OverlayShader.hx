package shaders;

import flixel.system.FlxAssets.FlxShader;

class OverlayShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header
		
		uniform sampler2D bitmapOverlay;
		
		vec4 blendOverlay(vec4 base, vec4 blend) {
			return mix(base, mix(1.0 - 2.0 * (1.0 - base) * (1.0 - blend), 2.0 * base * blend, step(base, vec4(0.5))), blend.a);
		}
		
		void main() {
			vec4 base = texture2D(bitmap, openfl_TextureCoordv);
			vec4 blend = texture2D(bitmapOverlay, openfl_TextureCoordv);
			gl_FragColor = blendOverlay(base, blend);
		}')
	
	public function new()
	{
		super();
	}
}
