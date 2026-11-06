/* Included into a copy of tests/fuzz_keys.c by tests/undo/fuzz_utf8.sh.
 * Log lines, all appended to $UTF8_LOG:
 *   SEED seed start=<class of E.buf at start>
 *   ROW seed key keyname class name row hex      first sight of this invalid row in this buffer
 *   LEAD seed key class name "what"              the fuzzer's own first lead for this seed
 *   END seed                                     the sequence ran out of keys
 *   WRITE / REFUSED ...                          from the hook in fileio.c
 * Keeps at most 400 ROW lines per seed. */
#include <fcntl.h>

static void keyName(const struct fkey *k, char *out, size_t n);

static uint32_t uc_seen[4096];
static int uc_nseen, uc_nlogged;
static uint32_t uc_seed;
static struct buffer *uc_start_buf; /* the unnamed buffer fillBuffer filled */

static void ucWrite(const char *line, int n) {
	const char *lg = getenv("UTF8_LOG");
	if (!lg)
		return;
	int fd = open(lg, O_WRONLY | O_APPEND | O_CREAT, 0666);
	if (fd >= 0) {
		if (write(fd, line, (size_t)n) < 0) {
		}
		close(fd);
	}
}

static const char *ucClass(struct buffer *b) {
	if (b == E.minibuf)
		return "minibuffer";
	if (b->special_buffer)
		return "special";
	if (b->filename == NULL)
		return "unnamed";
	if (b == uc_start_buf)
		return "unnamed-then-named";
	return "file";
}

static uint32_t ucHash(struct buffer *b, const uint8_t *s, int n) {
	uint32_t h = 2166136261u ^ (uint32_t)(uintptr_t)b;
	for (int i = 0; i < n; i++)
		h = (h ^ s[i]) * 16777619u;
	return h ? h : 1;
}

static int ucFirstSight(uint32_t h) {
	for (int i = 0; i < uc_nseen; i++)
		if (uc_seen[i] == h)
			return 0;
	if (uc_nseen < 4096)
		uc_seen[uc_nseen++] = h;
	return 1;
}

static void ucScan(struct buffer *b, int key) {
	char kn[64];
	struct fkey fk;
	memset(&fk, 0, sizeof(fk));
	fk.key = key;
	if (kpos > 0 && key == KEY_UNICODE)
		fk = keys[kpos - 1];
	keyName(&fk, kn, sizeof(kn));
	for (int i = 0; i < b->numrows; i++) {
		erow *r = &b->row[i];
		if (utf8_validate(r->chars, r->size))
			continue;
		if (!ucFirstSight(ucHash(b, r->chars, r->size)) || uc_nlogged >= 400)
			continue;
		uc_nlogged++;
		int cap = r->size * 2 + 400;
		char *line = xmalloc((size_t)cap);
		int n = snprintf(line, (size_t)cap, "ROW %u %d %s %s %.60s %d ", uc_seed, kpos, kn,
				 ucClass(b), b->filename ? b->filename : "-", i);
		for (int k = 0; k < r->size; k++)
			n += snprintf(line + n, (size_t)(cap - n), "%02x", r->chars[k]);
		n += snprintf(line + n, (size_t)(cap - n), "\n");
		ucWrite(line, n);
		free(line);
	}
}

void utf8CheckAll(int key) {
	for (struct buffer *b = E.headbuf; b; b = b->next)
		ucScan(b, key);
	if (E.minibuf)
		ucScan(E.minibuf, key);
}

void utf8LeadSeen(int k, const char *what) {
	char line[400];
	int n = snprintf(line, sizeof(line), "LEAD %u %d %s %.60s \"%s\"\n", uc_seed, k, ucClass(E.buf),
			 E.buf->filename ? E.buf->filename : "-", what);
	ucWrite(line, n);
}

/* Reached only if the sequence ran out of keys. C-x C-c ends it through exit() first,
 * so its exit status is 0 and the fuzzer's report leaves out any lead it had. */
void utf8End(uint32_t seed) {
	char line[100];
	int n = snprintf(line, sizeof(line), "END %u\n", seed);
	ucWrite(line, n);
}

void utf8CheckStart(uint32_t seed) {
	uc_seed = seed;
	uc_nseen = 0;
	uc_nlogged = 0;
	uc_start_buf = NULL;
	for (struct buffer *b = E.headbuf; b; b = b->next)
		if (b->filename == NULL)
			uc_start_buf = b;
	char line[200];
	int n = snprintf(line, sizeof(line), "SEED %u start=%s\n", seed, ucClass(E.buf));
	ucWrite(line, n);
	/* Rows already invalid before any key: key 0, keyname "start". */
	for (struct buffer *b = E.headbuf; b; b = b->next)
		for (int i = 0; i < b->numrows; i++) {
			erow *r = &b->row[i];
			if (utf8_validate(r->chars, r->size) || !ucFirstSight(ucHash(b, r->chars, r->size)))
				continue;
			int cap = r->size * 2 + 400;
			char *l2 = xmalloc((size_t)cap);
			int m = snprintf(l2, (size_t)cap, "ROW %u 0 start %s %.60s %d ", seed, ucClass(b),
					 b->filename ? b->filename : "-", i);
			for (int k = 0; k < r->size; k++)
				m += snprintf(l2 + m, (size_t)(cap - m), "%02x", r->chars[k]);
			m += snprintf(l2 + m, (size_t)(cap - m), "\n");
			ucWrite(l2, m);
			free(l2);
		}
}
