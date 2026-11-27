SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: kernel iso test clean

kernel:
	bash kernel/fetch.sh
	bash kernel/build.sh

iso:
	@[[ "$$(id -u)" -eq 0 ]] || { echo "ERROR: make iso must run as root" >&2; exit 1; }
	mkdir -p out
	cd live && lb clean && lb config && lb build 2>&1 | tee ../out/build.log
	mv live/vdtos-amd64.hybrid.iso out/

test:
	bash tests/run.sh
	bash tests/smoke.sh

clean:
	cd live && lb clean
	rm -rf build out
