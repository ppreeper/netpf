.PHONY: all setup build smoke check test clean incus-setup incus-build

all: build smoke

setup:
	sh scripts/build-image.sh setup

build:
	sh scripts/build-image.sh build

smoke:
	sh scripts/build-image.sh smoke

check:
	sh scripts/build-image.sh check

test:
	sh -n scripts/build-image.sh
	sh scripts/build-image.sh config
	sh -n scripts/incus-build.sh
	sh scripts/incus-build.sh config

clean:
	sh scripts/build-image.sh clean

incus-setup:
	sh scripts/incus-build.sh setup

incus-build:
	sh scripts/incus-build.sh build
