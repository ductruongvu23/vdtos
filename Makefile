SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: kernel iso test clean

kernel:
	bash kernel/fetch.sh
	bash kernel/build.sh

iso:
	mkdir -p out
	cd live && sudo lb clean && lb config && sudo lb build 2>&1 | tee ../out/build.log
	mv live/vdtos-amd64.hybrid.iso out/

test:
	bash tests/run.sh
	bash tests/smoke.sh

clean:
	cd live && sudo lb clean
	rm -rf build out
