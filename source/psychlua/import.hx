#if (!macro)
#if HSCRIPT_SCRIPTED_CLASSES

import Reflect as CustomReflect;
import Type as CustomType;

#else

import insanity.custom.InsanityReflect as CustomReflect;
import insanity.custom.InsanityType as CustomType;

#end
#end