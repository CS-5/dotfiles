/*
 * kbd-backlight-auto - macOS-style keyboard backlight for the ThinkPad T14 Gen 2i.
 *
 * Lights the keyboard on the first keystroke, keeps it lit while you type, and
 * drops it after a short idle window or as soon as the lid closes.
 *
 * Why a daemon at all: ThinkPad Fn+Space is handled entirely in EC firmware and
 * never reaches Hyprland, so there is no key event a keybinding could hang off.
 * This watches the keyboard's evdev node directly instead.
 *
 * Fn+Space stays your brightness control. The kernel reports firmware-driven
 * brightness changes through the LED's brightness_hw_changed attribute, so the
 * daemon sees your Fn+Space presses as events and adopts whatever level you
 * pick for auto-on from then on, including 0, which reads as "leave it off".
 *
 * Nothing here polls. The process sits in a single poll() over three
 * descriptors (keyboard, lid, brightness_hw_changed) and wakes only on a real
 * event, plus once to end the idle countdown. While the keyboard is dark it
 * blocks indefinitely at zero cost.
 *
 * Note on brightness_hw_changed: sysfs poll() returns POLLERR|POLLPRI
 * immediately on the first call. You have to lseek+read once to complete the
 * handshake, after which it blocks until the next *hardware* change and stays
 * quiet for writes we make ourselves.
 *
 * Usage:
 *   kbd-backlight-auto              run the daemon (what the systemd unit does)
 *   kbd-backlight-auto cycle        next level, wrapping off -> low -> high -> off
 *   kbd-backlight-auto up|down      step the level
 *   kbd-backlight-auto set <n>      set the level outright (0 disables the light)
 *   kbd-backlight-auto get          print the stored level
 *
 * Environment (the systemd unit sets these):
 *   KBD_BACKLIGHT_IDLE   seconds of no typing before the light drops (default 8)
 *   KBD_BACKLIGHT_LEVEL  level used before one has ever been chosen  (default 1)
 *   KBD_BACKLIGHT_DEV    override the keyboard evdev path
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <glob.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define KBD_DEV_DEFAULT "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
#define LID_DEV         "/dev/input/by-path/platform-PNP0C0D:00-event"
#define LID_STATE       "/proc/acpi/button/lid/LID/state"

static char brightness_path[PATH_MAX];
static char hw_changed_path[PATH_MAX];
static char state_path[PATH_MAX];
static int  max_level = 2;
static int  idle_secs = 8;
static int  default_level = 1;

static volatile sig_atomic_t stop_requested = 0;

static void on_signal(int sig) { (void)sig; stop_requested = 1; }

/* ------------------------------------------------------------- small I/O */

static int read_int_file(const char *path, int *out)
{
	char buf[32];
	int fd = open(path, O_RDONLY);
	if (fd < 0)
		return -1;
	ssize_t n = read(fd, buf, sizeof buf - 1);
	close(fd);
	if (n <= 0)
		return -1;
	buf[n] = '\0';
	*out = (int)strtol(buf, NULL, 10);
	return 0;
}

static int write_int_file(const char *path, int value)
{
	char buf[32];
	int fd = open(path, O_WRONLY);
	if (fd < 0)
		return -1;
	int len = snprintf(buf, sizeof buf, "%d", value);
	ssize_t n = write(fd, buf, (size_t)len);
	close(fd);
	return n == len ? 0 : -1;
}

/* mkdir -p for the state file's parent. */
static void mkdir_parents(const char *path)
{
	char tmp[PATH_MAX + 8];
	snprintf(tmp, sizeof tmp, "%s", path);
	for (char *p = tmp + 1; *p; p++) {
		if (*p != '/')
			continue;
		*p = '\0';
		mkdir(tmp, 0755);
		*p = '/';
	}
}

/* ------------------------------------------------------------------ LED */

/*
 * Resolve the LED by pattern so this keeps working if the node is ever renamed.
 * The udev rule in /etc/udev/rules.d/99-kbd-backlight.rules gives group 'input'
 * write access to brightness, so no helper and no logind session are needed.
 */
static int find_led(void)
{
	glob_t g;
	if (glob("/sys/class/leds/*kbd_backlight*", 0, NULL, &g) != 0 || g.gl_pathc == 0) {
		globfree(&g);
		return -1;
	}
	char max_path[PATH_MAX];
	snprintf(brightness_path, sizeof brightness_path, "%s/brightness", g.gl_pathv[0]);
	snprintf(hw_changed_path, sizeof hw_changed_path, "%s/brightness_hw_changed", g.gl_pathv[0]);
	snprintf(max_path, sizeof max_path, "%s/max_brightness", g.gl_pathv[0]);
	globfree(&g);

	if (read_int_file(max_path, &max_level) < 0 || max_level < 1)
		max_level = 2;
	return 0;
}

static int led_read(void)
{
	int v = 0;
	read_int_file(brightness_path, &v);
	return v;
}

static int led_write(int value) { return write_int_file(brightness_path, value) == 0; }

/* --------------------------------------------------------------- level */

static int clamp_level(int level)
{
	if (level < 0)
		return 0;
	return level > max_level ? max_level : level;
}

static int level_read(void)
{
	int level;
	if (read_int_file(state_path, &level) < 0)
		level = default_level;
	return clamp_level(level);
}

static void level_write(int level)
{
	char tmp[PATH_MAX + 8];
	mkdir_parents(state_path);
	snprintf(tmp, sizeof tmp, "%s.tmp", state_path);

	int fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd < 0)
		return;
	char buf[32];
	int len = snprintf(buf, sizeof buf, "%d\n", level);
	if (write(fd, buf, (size_t)len) != len) {
		close(fd);
		unlink(tmp);
		return;
	}
	close(fd);
	rename(tmp, state_path);
}

static int lid_closed(void)
{
	char buf[128];
	int fd = open(LID_STATE, O_RDONLY);
	if (fd < 0)
		return 0;
	ssize_t n = read(fd, buf, sizeof buf - 1);
	close(fd);
	if (n <= 0)
		return 0;
	buf[n] = '\0';
	return strstr(buf, "closed") != NULL;
}

/* ------------------------------------------------------------- CLI half */

static void osd(int level)
{
	char pct[16];
	snprintf(pct, sizeof pct, "%d", level * 100 / max_level);

	pid_t pid = fork();
	if (pid == 0) {
		execlp("omarchy-osd", "omarchy-osd", "-i", "keyboard", "-p", pct, (char *)NULL);
		_exit(127);
	}
	if (pid > 0)
		waitpid(pid, NULL, 0);
}

static void apply_level(int level)
{
	level = clamp_level(level);
	level_write(level);
	/*
	 * Turning off applies now; turning up only applies if the keyboard is
	 * already lit. Lighting a dark keyboard is the daemon's job, on a keystroke.
	 */
	if (level == 0 || led_read() > 0)
		led_write(level);
	osd(level);
	printf("%d\n", level);
}

/* --------------------------------------------------------------- daemon */

static int open_input(const char *path)
{
	return open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
}

/* Consume everything queued. Returns 0 if the device went away. */
static int drain(int fd)
{
	char buf[4096];
	for (;;) {
		ssize_t n = read(fd, buf, sizeof buf);
		if (n > 0)
			continue;
		if (n == 0)
			return 0;
		if (errno == EAGAIN || errno == EWOULDBLOCK)
			return 1;
		if (errno == EINTR)
			continue;
		return 0;
	}
}

static double now_monotonic(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static int daemon_loop(const char *kbd_dev)
{
	int kbd_fd = open_input(kbd_dev);
	if (kbd_fd < 0) {
		fprintf(stderr, "cannot open %s: %s (is this user in the 'input' group?)\n",
		        kbd_dev, strerror(errno));
		return 1;
	}
	int lid_fd = open_input(LID_DEV); /* optional */

	/* Firmware-driven brightness changes (Fn+Space) arrive here. */
	int hw_fd = open(hw_changed_path, O_RDONLY | O_CLOEXEC);
	if (hw_fd >= 0) {
		/* Complete the sysfs poll handshake so later polls block on real changes. */
		char scratch[32];
		lseek(hw_fd, 0, SEEK_SET);
		/* The value at startup is not interesting; only the re-arm matters. */
		(void)!read(hw_fd, scratch, sizeof scratch);
	}

	struct pollfd fds[3];
	int nfds = 0;
	int kbd_i = nfds;
	fds[nfds].fd = kbd_fd;   fds[nfds].events = POLLIN;  nfds++;
	int hw_i = -1;
	if (lid_fd >= 0) { fds[nfds].fd = lid_fd; fds[nfds].events = POLLIN; nfds++; }
	if (hw_fd  >= 0) { hw_i  = nfds; fds[nfds].fd = hw_fd;  fds[nfds].events = POLLPRI | POLLERR; nfds++; }

	int lit = 0;
	double last_activity = 0.0;
	led_write(0);

	while (!stop_requested) {
		/* Only the idle countdown needs a timer. Dark means block indefinitely. */
		int timeout = -1;
		if (lit) {
			double remaining = idle_secs - (now_monotonic() - last_activity);
			timeout = remaining > 0 ? (int)(remaining * 1000) : 0;
		}

		int ready = poll(fds, (nfds_t)nfds, timeout);
		if (ready < 0) {
			if (errno == EINTR)
				continue;
			break;
		}

		double now = now_monotonic();
		int typed = 0;
		int adopted = -1;

		for (int i = 0; i < nfds; i++) {
			if (!fds[i].revents)
				continue;
			if (i == hw_i) {
				/* Must re-read to re-arm the notification. */
				char buf[32];
				lseek(hw_fd, 0, SEEK_SET);
				ssize_t n = read(hw_fd, buf, sizeof buf - 1);
				if (n > 0) {
					buf[n] = '\0';
					adopted = (int)strtol(buf, NULL, 10);
				}
				continue;
			}
			if (!drain(fds[i].fd)) {
				/* Device vanished (suspend, re-enumeration). Let systemd restart us. */
				return 0;
			}
			if (i == kbd_i)
				typed = 1;
		}

		/* Fn+Space told us what "on" should mean from now on. */
		if (adopted >= 0) {
			adopted = clamp_level(adopted);
			level_write(adopted);
			lit = adopted > 0;
			if (lit)
				last_activity = now;
		}

		if (lid_closed()) {
			if (lit) {
				led_write(0);
				lit = 0;
			}
		} else if (typed) {
			last_activity = now;
			if (!lit) {
				int level = level_read();
				if (level > 0 && led_write(level))
					lit = 1;
			}
		} else if (lit && now - last_activity >= idle_secs) {
			led_write(0);
			lit = 0;
		}
	}

	/* Leave the keyboard dark on the way out rather than stranding it lit. */
	led_write(0);
	return 0;
}

/* ----------------------------------------------------------------- main */

int main(int argc, char **argv)
{
	if (find_led() < 0) {
		fprintf(stderr, "no keyboard backlight LED found\n");
		return 1;
	}

	const char *env;
	if ((env = getenv("KBD_BACKLIGHT_IDLE")))
		idle_secs = atoi(env) > 0 ? atoi(env) : idle_secs;
	if ((env = getenv("KBD_BACKLIGHT_LEVEL")))
		default_level = atoi(env);

	const char *xdg_state = getenv("XDG_STATE_HOME");
	if (xdg_state && *xdg_state) {
		snprintf(state_path, sizeof state_path, "%s/kbd-backlight/level", xdg_state);
	} else {
		const char *home = getenv("HOME");
		snprintf(state_path, sizeof state_path, "%s/.local/state/kbd-backlight/level",
		         home ? home : "/tmp");
	}

	const char *cmd = argc > 1 ? argv[1] : "daemon";

	if (!strcmp(cmd, "get")) {
		printf("%d\n", level_read());
		return 0;
	}
	if (!strcmp(cmd, "cycle")) {
		apply_level((level_read() + 1) % (max_level + 1));
		return 0;
	}
	if (!strcmp(cmd, "up")) {
		apply_level(level_read() + 1);
		return 0;
	}
	if (!strcmp(cmd, "down")) {
		apply_level(level_read() - 1);
		return 0;
	}
	if (!strcmp(cmd, "set")) {
		if (argc < 3) {
			fprintf(stderr, "usage: kbd-backlight-auto set <0-%d>\n", max_level);
			return 1;
		}
		apply_level(atoi(argv[2]));
		return 0;
	}
	if (strcmp(cmd, "daemon")) {
		fprintf(stderr, "usage: kbd-backlight-auto [daemon|cycle|up|down|set <0-%d>|get]\n",
		        max_level);
		return 1;
	}

	struct sigaction sa = { 0 };
	sa.sa_handler = on_signal;
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGHUP, &sa, NULL);

	env = getenv("KBD_BACKLIGHT_DEV");
	return daemon_loop(env && *env ? env : KBD_DEV_DEFAULT);
}
