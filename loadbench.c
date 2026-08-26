/* Measures dlopen cost (dominated by dynamic relocation processing) and the
   private-dirty footprint a library leaves behind once loaded. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static double now_ns(void) {
  struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e9 + t.tv_nsec;
}

static int is_map_header(const char *l) {         /* "7f..-7f.. rw-p ... /path" */
  const char *p = l;
  while (*p && ((*p >= '0' && *p <= '9') || (*p >= 'a' && *p <= 'f'))) p++;
  return p != l && *p == '-';
}

static long private_dirty_kb(const char *needle) {
  FILE *f = fopen("/proc/self/smaps", "r");
  if (!f) return -1;
  char line[1024]; int in = 0; long total = 0;
  while (fgets(line, sizeof line, f)) {
    if (is_map_header(line)) in = strstr(line, needle) != NULL;
    else if (in && !strncmp(line, "Private_Dirty:", 14)) total += atol(line + 14);
  }
  fclose(f);
  return total;
}

static int cmpd(const void *a, const void *b) {
  double x = *(const double *)a, y = *(const double *)b;
  return x < y ? -1 : x > y;
}

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: %s <lib.so> [reps]\n", argv[0]); return 2; }
  const char *path = argv[1];
  int reps = argc > 2 ? atoi(argv[2]) : 400;

  void *h = dlopen(path, RTLD_NOW | RTLD_LOCAL);
  if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }
  dlclose(h);                                    /* warm the page cache */

  double *v = malloc(sizeof(double) * reps);
  for (int i = 0; i < reps; i++) {
    double t0 = now_ns();
    void *hh = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    double t1 = now_ns();
    if (!hh) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }
    dlclose(hh);
    v[i] = t1 - t0;
  }
  qsort(v, reps, sizeof(double), cmpd);

  h = dlopen(path, RTLD_NOW | RTLD_LOCAL);
  const char *base = strrchr(path, '/') ? strrchr(path, '/') + 1 : path;
  long dirty = private_dirty_kb(base);
  int (*have_rtti)(void) = (int (*)(void))dlsym(h, "hs_have_rtti");

  printf("%-24s : %s\n", "library", base);
  printf("%-24s : %s\n", "built with RTTI",
         have_rtti ? (have_rtti() ? "yes" : "no (-fno-rtti)") : "?");
  printf("%-24s : %8.1f us\n", "dlopen min",        v[0] / 1000.0);
  printf("%-24s : %8.1f us\n", "dlopen median",     v[reps / 2] / 1000.0);
  printf("%-24s : %8ld KB\n",  "Private_Dirty",     dirty);
  return 0;
}
