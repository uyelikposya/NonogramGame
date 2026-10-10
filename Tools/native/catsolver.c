// Kedi Bulmaca çözüm sayacı (generate_cat_levels.py hızlandırması).
// En kısıtlı grubu (satır/sütun/renk) önce dener; 225 bitlik kümeler 4 x uint64.
#include <stdint.h>
#include <string.h>

typedef struct { uint64_t w[4]; } bs;

static int N, LIMIT, FOUND;
static bs GROUPS[45];
static bs ATK[225];
static int REGION[225];
static int PLACED[15];
static int *OUT;

static inline void setbit(bs *a, int i) { a->w[i >> 6] |= (uint64_t)1 << (i & 63); }
static inline int popc(const bs *a) {
    return __builtin_popcountll(a->w[0]) + __builtin_popcountll(a->w[1]) + __builtin_popcountll(a->w[2]) + __builtin_popcountll(a->w[3]);
}
static inline bs band(const bs *a, const bs *b) {
    bs r; for (int i = 0; i < 4; i++) r.w[i] = a->w[i] & b->w[i]; return r;
}
static inline bs bandnot(const bs *a, const bs *b) {
    bs r; for (int i = 0; i < 4; i++) r.w[i] = a->w[i] & ~b->w[i]; return r;
}

static int rec(bs cand, uint64_t closed, int depth) {
    if (depth == N) {
        int cols[15];
        for (int k = 0; k < N; k++) cols[PLACED[k] / N] = PLACED[k] % N;
        memcpy(OUT + FOUND * N, cols, sizeof(int) * N);
        FOUND++;
        return FOUND >= LIMIT;
    }
    int best = -1, bestCount = 1 << 30;
    for (int g = 0; g < 3 * N; g++) {
        if (closed >> g & 1) continue;
        bs m = band(&cand, &GROUPS[g]);
        int k = popc(&m);
        if (k < bestCount) { best = g; bestCount = k; if (k <= 1) break; }
    }
    if (bestCount == 0) return 0;
    bs options = band(&cand, &GROUPS[best]);
    for (int w = 0; w < 4; w++) {
        uint64_t word = options.w[w];
        while (word) {
            int bit = __builtin_ctzll(word);
            word &= word - 1;
            int cell = w * 64 + bit;
            int r = cell / N, c = cell % N;
            uint64_t cl = closed | ((uint64_t)1 << r) | ((uint64_t)1 << (N + c)) | ((uint64_t)1 << (2 * N + REGION[cell]));
            PLACED[depth] = cell;
            bs next = bandnot(&cand, &ATK[cell]);
            if (rec(next, cl, depth + 1)) return 1;
        }
    }
    return 0;
}

// region: n*n renk dizini; out: limit*n sütun. Bulunan çözüm sayısını döner.
int find_solutions(int n, const int *region, int limit, int *out) {
    N = n; LIMIT = limit; FOUND = 0; OUT = out;
    memset(GROUPS, 0, sizeof(GROUPS));
    memset(ATK, 0, sizeof(ATK));
    for (int i = 0; i < n * n; i++) REGION[i] = region[i];
    for (int r = 0; r < n; r++)
        for (int c = 0; c < n; c++) {
            int i = r * n + c;
            setbit(&GROUPS[r], i);
            setbit(&GROUPS[n + c], i);
            setbit(&GROUPS[2 * n + region[i]], i);
        }
    for (int r = 0; r < n; r++)
        for (int c = 0; c < n; c++) {
            int i = r * n + c;
            bs m = GROUPS[r];
            for (int k = 0; k < 4; k++) m.w[k] |= GROUPS[n + c].w[k] | GROUPS[2 * n + region[i]].w[k];
            for (int rr = r - 1; rr <= r + 1; rr++)
                for (int cc = c - 1; cc <= c + 1; cc++)
                    if (rr >= 0 && rr < n && cc >= 0 && cc < n) setbit(&m, rr * n + cc);
            ATK[i] = m;
        }
    bs full; memset(&full, 0, sizeof(full));
    for (int i = 0; i < n * n; i++) setbit(&full, i);
    rec(full, 0, 0);
    return FOUND;
}
