VERSION ?= 1.0.0
ZIP_NAME := fail2ban-setup-v$(VERSION).zip
DIST_DIR := dist
TAG := v$(VERSION)

.PHONY: all lint dry-run tag release clean

all: lint

lint:
	bash -n install_fail2ban.sh
	bash tests/smoke.sh

dry-run:
	./install_fail2ban.sh --dry-run --yes

tag:
	git tag -a $(TAG) -m "Release $(TAG)" 2>/dev/null || true
	git push origin $(TAG)
	git push gitlab $(TAG)

release: tag
	mkdir -p $(DIST_DIR)
	git archive --format=zip --prefix=fail2ban-setup-$(TAG)/ -o $(DIST_DIR)/$(ZIP_NAME) HEAD
	gh release view $(TAG) >/dev/null 2>&1 && \
		gh release upload $(TAG) $(DIST_DIR)/$(ZIP_NAME) --clobber || \
		gh release create $(TAG) $(DIST_DIR)/$(ZIP_NAME) \
			--title "$(TAG)" --notes-file RELEASE_NOTES.md
	glab release view $(TAG) >/dev/null 2>&1 && \
		glab release upload $(TAG) $(DIST_DIR)/$(ZIP_NAME) || \
		glab release create $(TAG) $(DIST_DIR)/$(ZIP_NAME) \
			--name "$(TAG)" --notes-file RELEASE_NOTES.md

clean:
	rm -rf $(DIST_DIR)
