ifdef SIMULATOR
export TARGET = simulator:clang:latest:8.0
else
export TARGET = iphone:clang:latest:7.0
	ifeq ($(debug),0)
		export ARCHS = armv7 arm64 arm64e
	else
		export ARCHS = arm64 arm64e
	endif
endif

TWEAK_NAME = FPSIndicator

FPSIndicator_FILES = Tweak.x
FPSIndicator_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -include Prefix.pch

FPSIndicator_FILES += libcolorpicker/libcolorpicker.mm

SUBPROJECTS += fpsindicatorpref

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 fatego" || true
	install.exec "killall -9 Preferences" || true
