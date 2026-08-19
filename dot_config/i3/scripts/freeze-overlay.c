/* freeze-overlay — show a frozen desktop frame on every monitor.
 *
 * One override-redirect window per monitor, backed by a MIT-SHM pixmap
 * (zero pixel transfer). Override-redirect keeps the WM out of the loop:
 * no focus steal, no pointer warp, no bar hide/show, no fade flicker.
 * All windows map before a single XSync, so every screen freezes at the
 * same instant. Windows are input-transparent; the caller (slop) grabs
 * the pointer. Exits on SIGTERM (X connection close destroys windows).
 *
 * Monitors come from Xinerama (instant; xrandr/RandR triggers a lazy
 * EDID reprobe that can stall >1.5s). Xinerama screen order matches
 * xrandr --listmonitors order on this setup.
 *
 * usage: freeze-overlay READY_FIFO FULL.bmp
 * build: gcc -O2 -o freeze-overlay freeze-overlay.c -lX11 -lXext -lXinerama
 */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/XShm.h>
#include <X11/extensions/Xinerama.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <unistd.h>

static void on_term(int sig) { (void)sig; exit(0); }

/* minimal BMP reader: 24 or 32 bpp, BI_RGB, bottom-up */
static unsigned char *read_bmp(const char *path, int *W, int *H, int *bpp)
{
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    unsigned char hdr[54];
    if (fread(hdr, 1, 54, f) != 54 || hdr[0] != 'B' || hdr[1] != 'M') {
        fclose(f); return NULL;
    }
    unsigned off = *(unsigned *)(hdr + 10);
    int w = *(int *)(hdr + 18);
    int h = *(int *)(hdr + 22);
    unsigned planes = *(unsigned short *)(hdr + 26);
    unsigned bits = *(unsigned short *)(hdr + 28);
    unsigned comp = *(unsigned *)(hdr + 30);
    if (planes != 1 || comp != 0 || h <= 0 || (bits != 24 && bits != 32)) {
        fclose(f); return NULL;
    }
    size_t sz = (size_t)w * h * 4;
    unsigned char *px = malloc(sz);
    if (!px) { fclose(f); return NULL; }
    size_t stride = ((size_t)w * bits / 8 + 3) & ~3u;
    unsigned char *raw = malloc(stride * (size_t)h);
    if (!raw) { free(px); fclose(f); return NULL; }
    fseek(f, off, SEEK_SET);
    if (fread(raw, 1, stride * (size_t)h, f) != stride * (size_t)h) {
        free(raw); free(px); fclose(f); return NULL;
    }
    fclose(f);
    for (int y = 0; y < h; y++) {
        unsigned char *src = raw + (size_t)(h - 1 - y) * stride; /* bottom-up */
        unsigned char *dst = px + (size_t)y * w * 4;
        if (bits == 24) {
            for (int x = 0; x < w; x++) {
                dst[x * 4 + 0] = src[x * 3 + 0];
                dst[x * 4 + 1] = src[x * 3 + 1];
                dst[x * 4 + 2] = src[x * 3 + 2];
                dst[x * 4 + 3] = 0;
            }
        } else {
            memcpy(dst, src, (size_t)w * 4);
        }
    }
    free(raw);
    *W = w; *H = h; *bpp = bits;
    return px;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: freeze-overlay READY_FIFO FULL.bmp\n");
        return 1;
    }
    const char *fifo = argv[1];

    Display *d = XOpenDisplay(NULL);
    if (!d) { perror("XOpenDisplay"); return 1; }
    if (!XShmQueryExtension(d)) { fprintf(stderr, "no MIT-SHM\n"); return 1; }
    int scr = DefaultScreen(d);
    if (DefaultDepth(d, scr) != 24) { fprintf(stderr, "unsupported depth\n"); return 1; }
    Window root = RootWindow(d, scr);
    Visual *visual = DefaultVisual(d, scr);

    int W, H, bpp;
    unsigned char *buf = read_bmp(argv[2], &W, &H, &bpp);
    if (!buf) { fprintf(stderr, "bad bmp\n"); return 1; }
    if (W != DisplayWidth(d, scr) || H != DisplayHeight(d, scr)) {
        fprintf(stderr, "bmp %dx%d != display %dx%d\n", W, H,
                DisplayWidth(d, scr), DisplayHeight(d, scr));
        return 1;
    }

    int nmon = 0;
    XineramaScreenInfo *mi = XineramaQueryScreens(d, &nmon);
    if (!mi || nmon < 1) { fprintf(stderr, "no xinerama screens\n"); return 1; }

    for (int m = 0; m < nmon; m++) {
        int x = mi[m].x_org, y = mi[m].y_org;
        int w = mi[m].width, h = mi[m].height;
        if (x < 0 || y < 0 || x + w > W || y + h > H) continue;
        size_t sz = (size_t)w * h * 4;

        int shmid = shmget(IPC_PRIVATE, sz, IPC_CREAT | 0600);
        if (shmid < 0) { perror("shmget"); return 1; }
        char *shmaddr = shmat(shmid, NULL, 0);
        if (shmaddr == (char *)-1) { perror("shmat"); return 1; }

        for (int i = 0; i < h; i++)
            memcpy(shmaddr + (size_t)i * w * 4,
                   buf + ((size_t)(y + i) * W + x) * 4, (size_t)w * 4);

        XShmSegmentInfo si = { .shmid = shmid, .shmaddr = shmaddr, .readOnly = False };
        XShmAttach(d, &si);
        Pixmap pm = XShmCreatePixmap(d, root, shmaddr, &si, w, h, 24);
        XSync(d, False);                 /* server attached before we let go */
        shmctl(shmid, IPC_RMID, NULL);   /* server keeps its own mapping */
        shmdt(shmaddr);

        XSetWindowAttributes attr = {
            .background_pixmap = pm,
            .override_redirect = True,
        };
        Window win = XCreateWindow(d, root, x, y, (unsigned)w, (unsigned)h, 0,
                                   24, InputOutput, visual,
                                   CWBackPixmap | CWOverrideRedirect, &attr);
        XMapWindow(d, win);
    }
    XFree(mi);
    free(buf);
    XSync(d, False);   /* everything rendered before we announce readiness */

    FILE *rf = fopen(fifo, "w");
    if (rf) { fputs("ready\n", rf); fclose(rf); }

    signal(SIGTERM, on_term);
    pause();
    return 0;
}
