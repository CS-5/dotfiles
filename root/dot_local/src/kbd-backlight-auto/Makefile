CFLAGS ?= -O2 -Wall -Wextra -std=c11 -D_FORTIFY_SOURCE=2
PREFIX ?= $(HOME)/.local

kbd-backlight-auto: kbd-backlight-auto.c
	$(CC) $(CFLAGS) -o $@ $<

install: kbd-backlight-auto
	install -Dm755 kbd-backlight-auto $(PREFIX)/bin/kbd-backlight-auto

clean:
	rm -f kbd-backlight-auto

.PHONY: install clean
